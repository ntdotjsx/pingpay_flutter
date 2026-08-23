export class BillAllocationService {
  /**
   * Distribute totalAmount evenly among participants.
   * Rounding differences are applied to the first `remainder` participants.
   */
  static allocateEvenly(totalAmount: number, participantsCount: number, ownerAmount = 0): number[] {
    if (participantsCount <= 0) return [];
    
    const participantPoolCents = this.getParticipantPoolCents(totalAmount, ownerAmount);
    const baseCents = Math.floor(participantPoolCents / participantsCount);
    const remainderCents = participantPoolCents % participantsCount;

    const result = new Array(participantsCount).fill(baseCents);
    for (let i = 0; i < remainderCents; i++) {
      result[i] += 1;
    }

    return result.map(cents => cents / 100);
  }

  static validateExactAllocation(totalAmount: number, amounts: number[], ownerAmount = 0): boolean {
    const participantPoolCents = this.getParticipantPoolCents(totalAmount, ownerAmount);
    const sumCents = amounts.reduce((acc, curr) => acc + Math.round(curr * 100), 0);
    return participantPoolCents === sumCents;
  }

  static getParticipantPoolCents(totalAmount: number, ownerAmount = 0): number {
    const totalCents = Math.round(totalAmount * 100);
    const ownerCents = Math.round(ownerAmount * 100);
    if (ownerCents < 0 || ownerCents > totalCents) {
      throw new Error("INVALID_OWNER_AMOUNT: Owner amount must be between 0 and total amount.");
    }
    return totalCents - ownerCents;
  }
}
