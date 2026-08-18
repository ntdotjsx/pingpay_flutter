import { t } from "elysia";

export const CreatePaymentSchema = t.Object({
  participantId: t.String({ format: "uuid", description: "Bill Item ID (debtor participant ID)" }),
  amount: t.Number({ minimum: 0.01, description: "Payment amount in THB" }),
  method: t.Optional(t.Union([t.Literal("full"), t.Literal("installment")], { default: "full" })),
  channel: t.Optional(t.Union([t.Literal("promptpay_qr"), t.Literal("bank_transfer"), t.Literal("cash")], { default: "promptpay_qr" })),
  slip: t.Optional(t.File({ description: "Uploaded slip image (JPEG, PNG, WEBP, HEIC)" })),
  qrData: t.Optional(t.String({ description: "Optional raw QR data extracted from slip" })),
  idempotencyKey: t.Optional(t.String({ description: "Client idempotency key" })),
});

export const ConfirmPaymentSchema = t.Object({
  idempotencyKey: t.Optional(t.String({ description: "Client idempotency key" })),
});

export const RejectPaymentSchema = t.Object({
  reason: t.String({ minLength: 1, maxLength: 256, description: "Reason for rejecting payment" }),
  idempotencyKey: t.Optional(t.String({ description: "Client idempotency key" })),
});

export const PaymentResponseSchema = t.Object({
  id: t.String({ format: "uuid" }),
  billItemId: t.String({ format: "uuid" }),
  payerId: t.String({ format: "uuid" }),
  amount: t.Number(),
  currency: t.String(),
  status: t.String(),
  installmentNumber: t.Optional(t.Union([t.Number(), t.Null()])),
  slipImageUrl: t.Optional(t.Union([t.String(), t.Null()])),
  slipOkReferenceId: t.Optional(t.Union([t.String(), t.Null()])),
  confirmedByOwnerAt: t.Optional(t.Union([t.Date(), t.Null()])),
  rejectedReason: t.Optional(t.Union([t.String(), t.Null()])),
  createdAt: t.Date(),
});
