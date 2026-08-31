import { db } from "../../db";
import {
  disputes,
  billItems,
  bills,
  users,
} from "../../db/schema";
import { eq, and, or, desc, inArray } from "drizzle-orm";
import { NotificationOutboxService } from "../notifications/notification-outbox.service";

export interface CreateDisputeDTO {
  billItemId: string;
  reason: string;
  evidenceUrl?: string;
}

export interface SubmitCreditorEvidenceDTO {
  note?: string;
  evidenceUrl?: string;
}

export class DisputeService {
  private outboxService: NotificationOutboxService;

  constructor(outbox?: NotificationOutboxService) {
    this.outboxService = outbox || new NotificationOutboxService();
  }

  /**
   * Debtor creates a new dispute for their bill item
   */
  async createDispute(userId: string, dto: CreateDisputeDTO) {
    // 1. Fetch bill item and parent bill
    const item = await db.query.billItems.findFirst({
      where: eq(billItems.id, dto.billItemId),
      with: {
        bill: {
          with: {
            owner: true,
          },
        },
        debtor: true,
      },
    });

    if (!item) {
      throw new Error("BILL_ITEM_NOT_FOUND");
    }

    if (item.debtorId !== userId) {
      throw new Error("FORBIDDEN_NOT_DEBTOR");
    }

    if (item.bill.status === "cancelled") {
      throw new Error("BILL_ALREADY_CANCELLED");
    }

    // 2. Check for existing active dispute
    const existingActiveDispute = await db.query.disputes.findFirst({
      where: and(
        eq(disputes.billItemId, dto.billItemId),
        or(eq(disputes.status, "open"), eq(disputes.status, "under_review"))
      ),
    });

    if (existingActiveDispute) {
      throw new Error("ACTIVE_DISPUTE_ALREADY_EXISTS");
    }

    // 3. Insert dispute record
    const [newDispute] = await db
      .insert(disputes)
      .values({
        billItemId: dto.billItemId,
        raisedById: userId,
        reason: dto.reason.trim(),
        evidenceUrl: dto.evidenceUrl,
        status: "open",
      })
      .returning();

    // 4. Enqueue DISPUTE_RAISED notification to creditor (bill owner)
    if (item.bill?.ownerId) {
      const debtorName =
        item.debtor?.displayName ||
        item.debtor?.fullName ||
        item.debtor?.userCode ||
        "ลูกหนี้";

      await this.outboxService.enqueueInTx(db, {
        eventType: "DISPUTE_RAISED",
        recipientUserId: item.bill.ownerId,
        channel: "push",
        deduplicationKey: `DISPUTE_RAISED:${newDispute.id}`,
        payload: {
          disputeId: newDispute.id,
          billId: item.bill.id,
          billTitle: item.bill.title || "รายการบิล",
          billItemId: item.id,
          debtorId: userId,
          debtorName,
          creditorId: item.bill.ownerId,
          disputedAmount: item.currentAmount,
          reason: dto.reason.trim(),
          evidenceUrl: dto.evidenceUrl,
        },
      });
    }

    return {
      ...newDispute,
      billItem: item,
    };
  }

  /**
   * Creditor (Bill Owner) submits counter-evidence and explanation
   */
  async submitCreditorEvidence(
    userId: string,
    disputeId: string,
    dto: SubmitCreditorEvidenceDTO
  ) {
    const dispute = await db.query.disputes.findFirst({
      where: eq(disputes.id, disputeId),
      with: {
        billItem: {
          with: {
            bill: true,
            debtor: true,
          },
        },
        raisedBy: true,
      },
    });

    if (!dispute) {
      throw new Error("DISPUTE_NOT_FOUND");
    }

    if (dispute.billItem?.bill?.ownerId !== userId) {
      throw new Error("FORBIDDEN_NOT_CREDITOR");
    }

    if (dispute.status !== "open" && dispute.status !== "under_review") {
      throw new Error("DISPUTE_ALREADY_RESOLVED");
    }

    const [updated] = await db
      .update(disputes)
      .set({
        creditorEvidenceNote: dto.note?.trim() || null,
        creditorEvidenceUrl: dto.evidenceUrl || null,
        creditorRespondedAt: new Date(),
        status: "under_review",
      })
      .where(eq(disputes.id, disputeId))
      .returning();

    return {
      ...updated,
      billItem: dispute.billItem,
    };
  }

  /**
   * Get dispute details for a user (either debtor or creditor)
   */
  async getDisputeDetail(userId: string, disputeId: string) {
    const dispute = await db.query.disputes.findFirst({
      where: eq(disputes.id, disputeId),
      with: {
        billItem: {
          with: {
            bill: {
              with: {
                owner: true,
              },
            },
            debtor: true,
            payments: {
              with: {
                verifications: true,
              },
            },
          },
        },
        raisedBy: true,
        resolvedBy: true,
      },
    });

    if (!dispute) {
      throw new Error("DISPUTE_NOT_FOUND");
    }

    const isDebtor = dispute.raisedById === userId;
    const isCreditor = dispute.billItem?.bill?.ownerId === userId;

    if (!isDebtor && !isCreditor) {
      // Check if user is developer/admin
      const user = await db.query.users.findFirst({
        where: eq(users.id, userId),
      });
      if (user?.role !== "developer") {
        throw new Error("FORBIDDEN");
      }
    }

    return dispute;
  }

  /**
   * List disputes relevant to the user (either raised by them or on bills they own)
   */
  async getUserDisputes(userId: string) {
    // 1. Get bill IDs owned by this user
    const ownedBills = await db.query.bills.findMany({
      where: eq(bills.ownerId, userId),
      columns: { id: true },
    });
    const ownedBillIds = ownedBills.map((b) => b.id);

    // 2. Get billItem IDs for owned bills
    let ownedBillItemIds: string[] = [];
    if (ownedBillIds.length > 0) {
      const ownedItems = await db.query.billItems.findMany({
        where: inArray(billItems.billId, ownedBillIds),
        columns: { id: true },
      });
      ownedBillItemIds = ownedItems.map((i) => i.id);
    }

    // 3. Find disputes raised by user OR for bills owned by user
    const conditions = [eq(disputes.raisedById, userId)];
    if (ownedBillItemIds.length > 0) {
      conditions.push(inArray(disputes.billItemId, ownedBillItemIds));
    }

    const rows = await db.query.disputes.findMany({
      where: or(...conditions),
      with: {
        billItem: {
          with: {
            bill: {
              with: {
                owner: true,
              },
            },
            debtor: true,
          },
        },
        raisedBy: true,
      },
      orderBy: [desc(disputes.createdAt)],
    });

    return rows.map((d) => ({
      ...d,
      isDebtor: d.raisedById === userId,
      isCreditor: d.billItem?.bill?.ownerId === userId,
    }));
  }
}
