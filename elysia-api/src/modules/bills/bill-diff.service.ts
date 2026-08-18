export interface BillDiff {
  bill?: {
    title?: { old: string | null; new: string | null };
    totalAmount?: { old: string; new: string };
  };
  participants?: Array<{
    debtorId: string;
    oldAmount: string;
    newAmount: string;
  }>;
}

export class BillDiffService {
  static diff(
    oldBill: { title: string | null; totalAmount: string },
    newBill: { title: string | null; totalAmount: string },
    oldParticipants: Array<{ debtorId: string; currentAmount: string }>,
    newParticipants: Array<{ debtorId: string; currentAmount: string }>
  ): BillDiff {
    const diffResult: BillDiff = {};

    // Bill metadata diff
    const billDiff: NonNullable<BillDiff["bill"]> = {};
    if (oldBill.title !== newBill.title) {
      billDiff.title = { old: oldBill.title, new: newBill.title };
    }
    if (oldBill.totalAmount !== newBill.totalAmount) {
      billDiff.totalAmount = { old: oldBill.totalAmount, new: newBill.totalAmount };
    }
    if (Object.keys(billDiff).length > 0) {
      diffResult.bill = billDiff;
    }

    // Participants diff
    const participantDiffs: NonNullable<BillDiff["participants"]> = [];
    const oldMap = new Map(oldParticipants.map((p) => [p.debtorId, p.currentAmount]));

    for (const np of newParticipants) {
      const oldAmount = oldMap.get(np.debtorId);
      if (oldAmount !== undefined && oldAmount !== np.currentAmount) {
        participantDiffs.push({
          debtorId: np.debtorId,
          oldAmount,
          newAmount: np.currentAmount,
        });
      }
    }

    if (participantDiffs.length > 0) {
      diffResult.participants = participantDiffs;
    }

    return diffResult;
  }
}
