import { BillRepository } from "./bill.repository";
import { BillAllocationService } from "./bill-allocation.service";
import { BillPolicy } from "./bill.policy";
import { BillDiffService } from "./bill-diff.service";
import { defaultNotificationService, NotificationService } from "./bill-notification.service";
import { BillWriteoffService, WriteOffRequestDTO } from "./bill-writeoff.service";
import { BillAdjustmentService, AdjustmentRequestDTO } from "./bill-adjustment.service";
import { defaultOCRService, OCRService } from "./ocr.service";

export interface CreateBillDTO {
  title?: string;
  description?: string;
  totalAmount: number;
  currency?: string;
  groupId?: string;
  participants: Array<{ userId: string; amount?: number }>;
  allocationMethod?: "evenly" | "exact" | "itemized";
  itemsBreakdown?: any;
}

export interface EditBillDTO {
  title?: string;
  description?: string;
  totalAmount?: number;
  itemsBreakdown?: any;
  version?: number;
}

export class BillService {
  private repo = new BillRepository();
  private writeoffService: BillWriteoffService;
  private adjustmentService: BillAdjustmentService;

  constructor(
    private notificationService: NotificationService = defaultNotificationService,
    private ocrService: OCRService = defaultOCRService
  ) {
    this.writeoffService = new BillWriteoffService(notificationService);
    this.adjustmentService = new BillAdjustmentService(notificationService);
  }

  async createBill(ownerId: string, dto: CreateBillDTO) {
    if (!dto.participants || dto.participants.length === 0) {
      throw new Error("INVALID_AMOUNT: Bill must have at least one participant.");
    }

    if (dto.totalAmount <= 0) {
      throw new Error("INVALID_AMOUNT: Total amount must be greater than 0.");
    }

    // Check duplicate participants
    const userIds = dto.participants.map((p) => p.userId);
    const uniqueUserIds = new Set(userIds);
    if (uniqueUserIds.size !== userIds.length) {
      throw new Error("DUPLICATE_PARTICIPANT: A user cannot be added multiple times to the same bill.");
    }

    let finalAllocations: { debtorId: string; amount: string }[] = [];

    if (dto.allocationMethod === "evenly" || !dto.allocationMethod) {
      const amounts = BillAllocationService.allocateEvenly(dto.totalAmount, dto.participants.length);
      finalAllocations = dto.participants.map((p, i) => ({
        debtorId: p.userId,
        amount: amounts[i].toFixed(2),
      }));
    } else {
      const amounts = dto.participants.map((p) => {
        if (p.amount === undefined || p.amount < 0) {
          throw new Error("INVALID_AMOUNT: Positive amount is required for exact allocation.");
        }
        return p.amount;
      });

      if (!BillAllocationService.validateExactAllocation(dto.totalAmount, amounts)) {
        throw new Error("TOTAL_MISMATCH: Allocated amounts sum does not match total amount.");
      }

      finalAllocations = dto.participants.map((p) => ({
        debtorId: p.userId,
        amount: p.amount!.toFixed(2),
      }));
    }

    return await this.repo.createBillWithItems(
      ownerId,
      {
        title: dto.title,
        totalAmount: dto.totalAmount.toFixed(2),
        currency: dto.currency || "THB",
        groupId: dto.groupId,
        itemsBreakdown: dto.itemsBreakdown,
      },
      finalAllocations
    );
  }

  async getBill(id: string) {
    const bill = await this.repo.getBillById(id);
    if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");
    return bill;
  }

  async editBill(userId: string, id: string, dto: EditBillDTO) {
    const bill = await this.repo.getBillById(id);
    if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

    BillPolicy.canEditBill(userId, bill.ownerId);

    if (bill.status !== "unpaid" && dto.totalAmount !== undefined) {
      throw new Error("PAID_DEBT_LOCKED: Cannot edit total amount of a bill that is partially or fully paid.");
    }

    return await this.repo.updateBill(id, userId, {
      title: dto.title,
      description: dto.description,
      totalAmount: dto.totalAmount !== undefined ? dto.totalAmount.toFixed(2) : undefined,
      itemsBreakdown: dto.itemsBreakdown,
    });
  }

  async editBillItem(userId: string, billId: string, participantId: string, newAmount: number) {
    const bill = await this.repo.getBillById(billId);
    if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

    BillPolicy.canEditBill(userId, bill.ownerId);

    const item = bill.items.find((i) => i.id === participantId || i.debtorId === participantId);
    if (!item) throw new Error("PARTICIPANT_NOT_FOUND: Participant not found in this bill.");

    if (item.isLocked || Number(item.amountPaid) >= Number(item.currentAmount)) {
      throw new Error("PAID_DEBT_LOCKED: This debt has already been fully paid and cannot be edited directly.");
    }

    if (newAmount < 0) {
      throw new Error("INVALID_AMOUNT: Participant amount cannot be negative.");
    }

    const billTotalCents = Math.round(Number(bill.totalAmount) * 100);
    const newTargetCents = Math.round(newAmount * 100);

    if (newTargetCents > billTotalCents) {
      throw new Error("INVALID_AMOUNT: Participant amount cannot exceed bill total amount.");
    }

    // Auto-redistribute remaining among other unpaid participants
    const otherParticipants = bill.items.filter((i) => i.id !== item.id);
    const remainingCents = billTotalCents - newTargetCents;

    let updatedAllocations: Array<{ id: string; debtorId: string; amount: string }> = [
      { id: item.id, debtorId: item.debtorId, amount: (newTargetCents / 100).toFixed(2) }
    ];

    if (otherParticipants.length > 0) {
      const otherAmounts = BillAllocationService.allocateEvenly(remainingCents / 100, otherParticipants.length);
      otherParticipants.forEach((op, index) => {
        updatedAllocations.push({
          id: op.id,
          debtorId: op.debtorId,
          amount: otherAmounts[index].toFixed(2)
        });
      });
    }

    // Update participants transactionally
    for (const alloc of updatedAllocations) {
      await this.repo.updateBillItemAmount(alloc.id, billId, userId, alloc.amount);
    }

    // Send notifications to affected debtors
    for (const alloc of updatedAllocations) {
      const originalItem = bill.items.find((i) => i.id === alloc.id);
      if (originalItem && originalItem.currentAmount !== alloc.amount) {
        try {
          await this.notificationService.notify({
            userId: alloc.debtorId,
            billId,
            billTitle: bill.title || "Bill",
            actorName: bill.owner?.displayName || "Bill Owner",
            type: "update",
            oldAmount: originalItem.currentAmount,
            newAmount: alloc.amount,
            timestamp: new Date()
          });
        } catch (e) {}
      }
    }

    return await this.repo.getBillById(billId);
  }

  async processOCRReceipt(file: File | Blob) {
    return await this.ocrService.extractReceipt(file);
  }

  async writeOffDebt(userId: string, billId: string, dto: WriteOffRequestDTO) {
    return await this.writeoffService.writeOffDebt(userId, billId, dto);
  }

  async adjustPaidDebt(userId: string, billId: string, dto: AdjustmentRequestDTO) {
    return await this.adjustmentService.adjustPaidDebt(userId, billId, dto);
  }
}
