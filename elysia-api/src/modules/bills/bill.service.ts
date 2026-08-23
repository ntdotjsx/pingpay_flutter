import { db } from "../../db";
import { BillRepository } from "./bill.repository";
import { BillAllocationService } from "./bill-allocation.service";
import { BillPolicy } from "./bill.policy";
import { BillDiffService } from "./bill-diff.service";
import { defaultNotificationService, NotificationService } from "./bill-notification.service";
import { BillWriteoffService, WriteOffRequestDTO } from "./bill-writeoff.service";
import { BillAdjustmentService, AdjustmentRequestDTO } from "./bill-adjustment.service";
import { defaultOCRService, OCRService } from "./ocr.service";
import { defaultNotificationOutboxService } from "../notifications/notification-outbox.service";
import { realtimeService } from "../../realtime/realtime.service";

export interface CreateBillDTO {
  title?: string;
  description?: string;
  totalAmount: number;
  ownerAmount?: number;
  currency?: string;
  groupId?: string;
  participants: Array<{ userId: string; amount?: number }>;
  allocationMethod?: "evenly" | "exact" | "itemized";
  itemsBreakdown?: any;
  receiptImageUrl?: string;
}

export interface EditBillDTO {
  title?: string;
  description?: string;
  totalAmount?: number;
  itemsBreakdown?: any;
  version?: number;
}

export class BillService {
  private repo: BillRepository;
  private writeoffService: BillWriteoffService;
  private adjustmentService: BillAdjustmentService;

  constructor(
    private notificationService: NotificationService = defaultNotificationService,
    private ocrService: OCRService = defaultOCRService,
    customDb: any = db
  ) {
    this.repo = new BillRepository(customDb);
    this.writeoffService = new BillWriteoffService(notificationService, customDb);
    this.adjustmentService = new BillAdjustmentService(notificationService, customDb);
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
    if (uniqueUserIds.has(ownerId)) {
      throw new Error("OWNER_CANNOT_BE_PARTICIPANT: The bill owner share must use ownerAmount, not a debt participant.");
    }

    const ownerAmount = dto.ownerAmount ?? 0;
    BillAllocationService.getParticipantPoolCents(dto.totalAmount, ownerAmount);

    let finalAllocations: { debtorId: string; amount: string }[] = [];

    if (dto.allocationMethod === "evenly" || !dto.allocationMethod) {
      const amounts = BillAllocationService.allocateEvenly(dto.totalAmount, dto.participants.length, ownerAmount);
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

      if (!BillAllocationService.validateExactAllocation(dto.totalAmount, amounts, ownerAmount)) {
        throw new Error("TOTAL_MISMATCH: Allocated amounts sum does not match total amount.");
      }

      finalAllocations = dto.participants.map((p) => ({
        debtorId: p.userId,
        amount: p.amount!.toFixed(2),
      }));
    }

    const createdBill = await this.repo.createBillWithItems(
      ownerId,
      {
        title: dto.title,
        description: dto.description,
        totalAmount: dto.totalAmount.toFixed(2),
        currency: dto.currency || "THB",
        groupId: dto.groupId,
        itemsBreakdown: dto.itemsBreakdown,
        receiptImageUrl: dto.receiptImageUrl,
      },
      finalAllocations
    );

    const fullCreatedBill = await this.repo.getBillById(createdBill.id);
    if (!fullCreatedBill) throw new Error("BILL_NOT_FOUND: Created bill not found.");
    const billMemberIds = await realtimeService.getBillMemberUserIds(fullCreatedBill.id);
    realtimeService.sendToUsers(
      billMemberIds,
      realtimeService.makeEvent(
        "bill.created",
        {
          billId: fullCreatedBill.id,
          createdBy: ownerId,
          memberIds: billMemberIds,
          bill: fullCreatedBill,
        },
        { resourceId: fullCreatedBill.id }
      )
    );

    // Enqueue real LINE notifications for all participants in outbox
    try {
      const ownerUser = fullCreatedBill.owner || await db.query.users?.findFirst?.({
        where: (u: any, { eq }: any) => eq(u.id, ownerId),
      });
      const creatorName = ownerUser?.displayName || ownerUser?.fullName || "เพื่อน";
      const { defaultNotificationOutboxService } = await import("../notifications/notification-outbox.service");

      for (const item of (fullCreatedBill.items || [])) {
        if (item.debtorId && item.debtorId !== ownerId) {
          await defaultNotificationOutboxService.enqueue({
            eventType: "BILL_CREATED",
            recipientUserId: item.debtorId,
            deduplicationKey: `BILL_CREATED:${fullCreatedBill.id}:${item.debtorId}`,
            payload: {
              billId: fullCreatedBill.id,
              billTitle: fullCreatedBill.title || "บิลค่าใช้จ่าย",
              participantDebtAmount: Number(item.currentAmount).toFixed(2),
              totalAmount: Number(fullCreatedBill.totalAmount).toFixed(2),
              currency: fullCreatedBill.currency || "THB",
              creatorName,
            },
          });
        }
      }
    } catch (err) {
      console.error("[BillService] Failed to enqueue BILL_CREATED notification:", err);
    }

    return fullCreatedBill;
  }

  async getBill(id: string, userId?: string) {
    const bill = await this.repo.getBillById(id);
    if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");
    if (userId) {
      const isOwner = bill.ownerId === userId;
      const isParticipant = bill.items.some((item) => item.debtorId === userId);
      if (!isOwner && !isParticipant) {
        throw new Error("UNAUTHORIZED: You do not have permission to view this bill.");
      }
    }
    return bill;
  }

  async getMyBills(userId: string) {
    return await this.repo.getBillsForUser(userId);
  }

  async editBill(userId: string, id: string, dto: EditBillDTO) {
    const bill = await this.repo.getBillById(id);
    if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

    BillPolicy.canEditBill(userId, bill.ownerId);

    if (bill.status !== "unpaid" && dto.totalAmount !== undefined) {
      throw new Error("PAID_DEBT_LOCKED: Cannot edit total amount of a bill that is partially or fully paid.");
    }

    const updated = await this.repo.updateBill(id, userId, {
      title: dto.title,
      description: dto.description,
      totalAmount: dto.totalAmount !== undefined ? dto.totalAmount.toFixed(2) : undefined,
      itemsBreakdown: dto.itemsBreakdown,
    });

    const fullBill = await this.repo.getBillById(id);
    await realtimeService.sendToBill(
      id,
      realtimeService.makeEvent(
        "bill.updated",
        {
          billId: id,
          updatedBy: userId,
          bill: fullBill ?? updated,
        },
        { resourceId: id }
      )
    );

    return fullBill ?? updated;
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
    const existingDebtorPoolCents = bill.items.reduce(
      (sum, it) => sum + Math.round(Number(it.currentAmount) * 100),
      0
    );
    const ownerCents = Math.max(0, billTotalCents - existingDebtorPoolCents);
    const newTargetCents = Math.round(newAmount * 100);

    const otherParticipants = bill.items.filter((i) => i.id !== item.id);
    let targetDebtorPoolCents = existingDebtorPoolCents;

    if (otherParticipants.length === 0) {
      targetDebtorPoolCents = newTargetCents;
    } else {
      targetDebtorPoolCents = Math.max(existingDebtorPoolCents, newTargetCents);
    }

    const effectiveBillTotalCents = ownerCents + targetDebtorPoolCents;
    if (effectiveBillTotalCents !== billTotalCents) {
      await this.repo.updateBill(billId, userId, {
        totalAmount: (effectiveBillTotalCents / 100).toFixed(2),
      });
    }

    const remainingCents = Math.max(0, targetDebtorPoolCents - newTargetCents);

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

        try {
          await defaultNotificationOutboxService.enqueue({
            eventType: "BILL_UPDATED",
            recipientUserId: alloc.debtorId,
            deduplicationKey: `BILL_UPDATED:${billId}:${alloc.debtorId}:${Date.now()}`,
            payload: {
              billId,
              billTitle: bill.title || "บิลค่าใช้จ่าย",
              editorId: userId,
              editorName: bill.owner?.displayName || bill.owner?.fullName || "เจ้าของบิล",
              participantId: alloc.id,
              oldAmount: originalItem.currentAmount,
              newAmount: alloc.amount,
            },
          });
        } catch (err) {
          console.error("[BillService] Failed to enqueue BILL_UPDATED notification:", err);
        }
      }
    }

    const updatedBill = await this.repo.getBillById(billId);
    await realtimeService.sendToBill(
      billId,
      realtimeService.makeEvent(
        "bill.updated",
        {
          billId,
          updatedBy: userId,
          bill: updatedBill,
        },
        { resourceId: billId }
      )
    );

    return updatedBill;
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

  async cancelBill(userId: string, billId: string, reason?: string) {
    const bill = await this.repo.getBillById(billId);
    if (!bill) throw new Error("BILL_NOT_FOUND: Bill not found.");

    BillPolicy.canEditBill(userId, bill.ownerId);

    const cancelled = await this.repo.cancelBill(billId, userId, reason);

    await realtimeService.sendToBill(
      billId,
      realtimeService.makeEvent(
        "bill.deleted",
        {
          billId,
          deletedBy: userId,
          reason,
        },
        { resourceId: billId }
      )
    );

    try {
      const canceller = await this.repo.getUserById(userId);
      const cancellerName = canceller?.displayName || canceller?.fullName || "เจ้าของบิล";

      for (const item of (bill.items || [])) {
        if (item.debtorId && item.debtorId !== userId) {
          await defaultNotificationOutboxService.enqueue({
            eventType: "BILL_CANCELLED",
            recipientUserId: item.debtorId,
            deduplicationKey: `BILL_CANCELLED:${billId}:${item.debtorId}`,
            payload: {
              billId,
              billTitle: bill.title || "บิลค่าใช้จ่าย",
              cancellerId: userId,
              cancellerName,
              participantId: item.id,
              reason,
            },
          });
        }
      }
    } catch (err) {
      console.error("[BillService] Failed to enqueue BILL_CANCELLED notification:", err);
    }

    return cancelled;
  }
}
