export class BillAllocationService {
  /**
   * Distribute totalAmount evenly among participants.
   * Rounding differences are applied to the first `remainder` participants.
   */
  static allocateEvenly(totalAmount: number, participantsCount: number): number[] {
    if (participantsCount <= 0) return [];
    
    const totalCents = Math.round(totalAmount * 100);
    const baseCents = Math.floor(totalCents / participantsCount);
    const remainderCents = totalCents % participantsCount;

    const result = new Array(participantsCount).fill(baseCents);
    for (let i = 0; i < remainderCents; i++) {
      result[i] += 1;
    }

    return result.map(cents => cents / 100);
  }

  static validateExactAllocation(totalAmount: number, amounts: number[]): boolean {
    const totalCents = Math.round(totalAmount * 100);
    const sumCents = amounts.reduce((acc, curr) => acc + Math.round(curr * 100), 0);
    return totalCents === sumCents;
  }
}
