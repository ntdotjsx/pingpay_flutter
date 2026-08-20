import { t } from "elysia";

export const ParticipantSchema = t.Object({
  userId: t.String({ format: "uuid", description: "User ID of the participant" }),
  amount: t.Optional(t.Number({ minimum: 0, description: "Allocated amount (required for exact allocation)" })),
});

export const ReceiptItemBreakdownSchema = t.Object({
  name: t.String({ description: "Name of item or menu" }),
  price: t.Number({ minimum: 0, description: "Price of single unit or total item price" }),
  quantity: t.Optional(t.Number({ minimum: 1, default: 1, description: "Quantity of items" })),
  allocatedToUserIds: t.Optional(t.Array(t.String({ format: "uuid" }), { description: "User IDs assigned to this specific item" })),
});

export const ItemsBreakdownSchema = t.Object({
  items: t.Array(ReceiptItemBreakdownSchema, { description: "List of items in the receipt" }),
  subtotal: t.Optional(t.Number({ minimum: 0, description: "Subtotal sum of items" })),
  serviceCharge: t.Optional(t.Object({
    ratePercent: t.Optional(t.Number({ minimum: 0 })),
    amount: t.Number({ minimum: 0 }),
  })),
  vat: t.Optional(t.Object({
    ratePercent: t.Optional(t.Number({ minimum: 0 })),
    amount: t.Number({ minimum: 0 }),
  })),
  discount: t.Optional(t.Number({ minimum: 0 })),
  totalAmount: t.Number({ minimum: 0.01, description: "Calculated total amount" }),
  formulaExplanation: t.Optional(t.String({ description: "Human-readable formula explanation: Subtotal + Service + VAT - Discount = Total" })),
});

export const CreateBillSchema = t.Object({
  title: t.Optional(t.String({ maxLength: 128, description: "Title of the bill" })),
  description: t.Optional(t.String({ description: "Description or notes for the bill" })),
  totalAmount: t.Number({ minimum: 0.01, description: "Total amount of the bill in THB" }),
  currency: t.Optional(t.String({ default: "THB", maxLength: 3, description: "3-letter currency code (defaults to THB)" })),
  groupId: t.Optional(t.String({ format: "uuid", description: "Optional group ID" })),
  participants: t.Array(ParticipantSchema, { minItems: 1, description: "List of participants in this bill" }),
  allocationMethod: t.Optional(t.Union([t.Literal("evenly"), t.Literal("exact"), t.Literal("itemized")], { default: "evenly" })),
  itemsBreakdown: t.Optional(ItemsBreakdownSchema),
  receiptImageUrl: t.Optional(t.String({ description: "Base64 encoded image or receipt image URL" })),
});

export const EditBillSchema = t.Object({
  title: t.Optional(t.String({ maxLength: 128, description: "Updated bill title or merchant name" })),
  description: t.Optional(t.String({ description: "Updated bill description" })),
  totalAmount: t.Optional(t.Number({ minimum: 0.01, description: "Updated total bill amount" })),
  itemsBreakdown: t.Optional(ItemsBreakdownSchema, { description: "Updated items breakdown, subtotal, VAT, or service charge" }),
  version: t.Optional(t.Number({ description: "Optimistic concurrency version or timestamp" })),
});

export const UpdateReceiptDraftSchema = t.Object({
  merchant: t.Optional(t.String({ maxLength: 128, description: "Updated merchant/restaurant name" })),
  items: t.Optional(t.Array(ReceiptItemBreakdownSchema, { description: "Updated list of line items" })),
  subtotal: t.Optional(t.Number({ minimum: 0, description: "Updated subtotal" })),
  serviceCharge: t.Optional(t.Object({
    ratePercent: t.Optional(t.Number({ minimum: 0 })),
    amount: t.Number({ minimum: 0 }),
  })),
  vat: t.Optional(t.Object({
    ratePercent: t.Optional(t.Number({ minimum: 0 })),
    amount: t.Number({ minimum: 0 }),
  })),
  discount: t.Optional(t.Number({ minimum: 0 })),
  totalAmount: t.Optional(t.Number({ minimum: 0.01, description: "Updated total amount" })),
});

export const EditBillItemSchema = t.Object({
  amount: t.Number({ minimum: 0, description: "New allocated amount for this participant" }),
});

export const WriteOffParticipantSchema = t.Object({
  participantId: t.String({ format: "uuid", description: "Participant/Bill item ID" }),
  amount: t.Number({ minimum: 0.01, description: "Amount of debt to write off" }),
});

export const WriteOffRequestSchema = t.Object({
  reason: t.Optional(t.String({ description: "Reason for writing off debt" })),
  idempotencyKey: t.Optional(t.String({ description: "Idempotency key to prevent duplicate requests" })),
  participants: t.Array(WriteOffParticipantSchema, { minItems: 1, description: "List of participants and write-off amounts" }),
});

export const AdjustmentRequestSchema = t.Object({
  participantId: t.String({ format: "uuid", description: "Participant/Bill item ID to adjust" }),
  newAmount: t.Number({ minimum: 0, description: "Corrected total debt amount" }),
  reason: t.Optional(t.String({ description: "Reason for correction" })),
  idempotencyKey: t.Optional(t.String({ description: "Idempotency key to prevent duplicate adjustments" })),
});
