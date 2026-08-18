import { describe, it, expect } from "bun:test";
import { PaymentStateMachine } from "../../../src/modules/payments/payment-state-machine";

describe("Unit: PaymentStateMachine", () => {
  it("should allow legal transitions", () => {
    expect(PaymentStateMachine.canTransition("pending_verification", "pending_owner_confirmation")).toBe(true);
    expect(PaymentStateMachine.canTransition("pending_verification", "verification_failed")).toBe(true);
    expect(PaymentStateMachine.canTransition("pending_owner_confirmation", "confirmed")).toBe(true);
    expect(PaymentStateMachine.canTransition("pending_owner_confirmation", "rejected")).toBe(true);
    expect(PaymentStateMachine.canTransition("confirmed", "refunded")).toBe(true);
  });

  it("should reject illegal transitions and throw", () => {
    expect(PaymentStateMachine.canTransition("confirmed", "pending_verification")).toBe(false);
    expect(PaymentStateMachine.canTransition("rejected", "confirmed")).toBe(false);
    expect(PaymentStateMachine.canTransition("verification_failed", "confirmed")).toBe(false);

    expect(() => {
      PaymentStateMachine.assertTransition("confirmed", "pending_verification");
    }).toThrow("PAYMENT_STATE_CONFLICT");

    expect(() => {
      PaymentStateMachine.assertTransition("rejected", "confirmed");
    }).toThrow("PAYMENT_STATE_CONFLICT");
  });
});
