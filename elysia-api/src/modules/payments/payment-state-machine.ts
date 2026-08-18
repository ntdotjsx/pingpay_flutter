import { paymentStatusEnum } from "../../db/schema";

export type PaymentStatus = (typeof paymentStatusEnum.enumValues)[number];

export class PaymentStateMachine {
  /**
   * Explicit valid transitions:
   * PENDING_VERIFICATION -> PENDING_OWNER_CONFIRMATION | VERIFICATION_FAILED | CANCELLED
   * PENDING_OWNER_CONFIRMATION -> CONFIRMED | REJECTED | CANCELLED
   * CONFIRMED -> REFUNDED
   * VERIFICATION_FAILED -> [TERMINAL]
   * REJECTED -> [TERMINAL]
   * CANCELLED -> [TERMINAL]
   * REFUNDED -> [TERMINAL]
   */
  private static validTransitions: Record<PaymentStatus, PaymentStatus[]> = {
    pending_verification: ["pending_owner_confirmation", "verification_failed", "cancelled"],
    pending_owner_confirmation: ["confirmed", "rejected", "cancelled"],
    confirmed: ["refunded"],
    verification_failed: [],
    rejected: [],
    cancelled: [],
    refunded: [],
  };

  /**
   * Validates if a transition from currentStatus to targetStatus is legally permitted.
   */
  static canTransition(currentStatus: PaymentStatus, targetStatus: PaymentStatus): boolean {
    const allowed = this.validTransitions[currentStatus] || [];
    return allowed.includes(targetStatus);
  }

  /**
   * Validates transition and throws descriptive business error if illegal.
   */
  static assertTransition(currentStatus: PaymentStatus, targetStatus: PaymentStatus): void {
    if (!this.canTransition(currentStatus, targetStatus)) {
      throw new Error(
        `PAYMENT_STATE_CONFLICT: Illegal state transition from '${currentStatus}' to '${targetStatus}'.`
      );
    }
  }

  /**
   * Checks if payment is in an active pending confirmation state.
   */
  static isPendingOwnerConfirmation(status: PaymentStatus): boolean {
    return status === "pending_owner_confirmation";
  }

  /**
   * Checks if payment is immutable (already confirmed).
   */
  static isConfirmed(status: PaymentStatus): boolean {
    return status === "confirmed";
  }
}
