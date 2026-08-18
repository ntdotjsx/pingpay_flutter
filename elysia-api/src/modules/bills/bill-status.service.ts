import { billStatusEnum, billItemStatusEnum } from "../../db/schema";

export type BillStatusType = (typeof billStatusEnum.enumValues)[number];
export type BillItemStatusType = (typeof billItemStatusEnum.enumValues)[number];

export interface ParticipantDebtState {
  originalDebt: number; // in THB
  currentAmount: number; // in THB (reflects manual edits / write-offs)
  amountPaid: number; // confirmed paid in THB
  amountWrittenOff: number; // confirmed write-off in THB
}

export interface BillStatusCalculationInput {
  participants: ParticipantDebtState[];
}

export interface ParticipantStatusResult {
  status: BillItemStatusType;
  remainingDebt: number;
  isFullySettled: boolean;
}

export interface BillStatusResult {
  status: BillStatusType;
  totalOriginalDebt: number;
  totalPaid: number;
  totalWrittenOff: number;
  totalRemaining: number;
  participantResults: ParticipantStatusResult[];
}

export class BillStatusService {
  /**
   * Deterministically calculates individual participant status:
   * - UNPAID: paid == 0, writtenOff == 0, remaining > 0
   * - PARTIALLY_PAID: (paid > 0 && remaining > 0) OR (paid > 0 && writtenOff > 0 && remaining == 0)
   * - PAID: remaining == 0 && paid >= currentAmount && writtenOff == 0
   * - WRITTEN_OFF: remaining == 0 && paid == 0 && writtenOff >= currentAmount
   */
  static calculateParticipantStatus(debt: ParticipantDebtState): ParticipantStatusResult {
    const currentCents = Math.round(debt.currentAmount * 100);
    const paidCents = Math.round(debt.amountPaid * 100);
    const writtenOffCents = Math.round(debt.amountWrittenOff * 100);

    const remainingCents = Math.max(0, currentCents - paidCents - writtenOffCents);
    const remainingDebt = remainingCents / 100;
    const isFullySettled = remainingCents === 0;

    let status: BillItemStatusType = "unpaid";

    if (remainingCents === 0) {
      if (paidCents > 0 && writtenOffCents === 0) {
        status = "paid";
      } else if (writtenOffCents > 0 && paidCents === 0) {
        status = "written_off";
      } else if (paidCents > 0 && writtenOffCents > 0) {
        status = "partially_paid"; // Settled with both payment & write-off
      } else {
        status = "paid"; // Default settled
      }
    } else {
      if (paidCents > 0 || writtenOffCents > 0) {
        status = "partially_paid";
      } else {
        status = "unpaid";
      }
    }

    return {
      status,
      remainingDebt,
      isFullySettled,
    };
  }

  /**
   * Deterministically calculates overall bill status from all participants:
   * - UNPAID: confirmedPaid == 0, writtenOff == 0, remaining > 0
   * - PARTIALLY_PAID: confirmedPaid > 0, remaining > 0
   * - FULLY_PAID: remaining == 0, confirmedPaid > 0, writtenOff == 0 (or all paid)
   * - PARTIALLY_WRITTEN_OFF: writtenOff > 0, confirmedPaid == 0, remaining > 0
   * - FULLY_WRITTEN_OFF: remaining == 0, confirmedPaid == 0, writtenOff > 0
   */
  static calculateBillStatus(input: BillStatusCalculationInput): BillStatusResult {
    const participantResults = input.participants.map((p) =>
      this.calculateParticipantStatus(p)
    );

    let totalOriginalCents = 0;
    let totalPaidCents = 0;
    let totalWrittenOffCents = 0;
    let totalRemainingCents = 0;

    for (let i = 0; i < input.participants.length; i++) {
      const p = input.participants[i];
      const r = participantResults[i];

      totalOriginalCents += Math.round(p.originalDebt * 100);
      totalPaidCents += Math.round(p.amountPaid * 100);
      totalWrittenOffCents += Math.round(p.amountWrittenOff * 100);
      totalRemainingCents += Math.round(r.remainingDebt * 100);
    }

    let status: BillStatusType = "unpaid";

    if (totalRemainingCents === 0) {
      if (totalPaidCents > 0 && totalWrittenOffCents === 0) {
        status = "fully_paid";
      } else if (totalWrittenOffCents > 0 && totalPaidCents === 0) {
        status = "fully_written_off";
      } else if (totalPaidCents > 0 && totalWrittenOffCents > 0) {
        status = "partially_paid"; // Mixed completion: covered by both
      } else {
        status = "fully_paid";
      }
    } else {
      if (totalPaidCents > 0) {
        status = "partially_paid";
      } else if (totalWrittenOffCents > 0) {
        status = "partially_written_off";
      } else {
        status = "unpaid";
      }
    }

    return {
      status,
      totalOriginalDebt: totalOriginalCents / 100,
      totalPaid: totalPaidCents / 100,
      totalWrittenOff: totalWrittenOffCents / 100,
      totalRemaining: totalRemainingCents / 100,
      participantResults,
    };
  }
}
