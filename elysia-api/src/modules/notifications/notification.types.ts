export type NotificationEventType =
  | "BILL_CREATED"
  | "BILL_UPDATED"
  | "BILL_WRITTEN_OFF"
  | "BILL_CANCELLED"
  | "PAYMENT_PENDING_CONFIRMATION"
  | "PAYMENT_CONFIRMED"
  | "PAYMENT_REJECTED"
  | "DEBT_WEEKLY_REMINDER"
  | "FRIEND_REQUEST_RECEIVED"
  | "FRIEND_REQUEST_ACCEPTED";

export type NotificationStatus =
  | "PENDING"
  | "PROCESSING"
  | "SENT"
  | "FAILED"
  | "CANCELLED"
  | "SKIPPED";

export interface BillCreatedPayload {
  billId: string;
  billTitle: string;
  creatorId: string;
  creatorName: string;
  participantId: string;
  participantDebtAmount: string;
  totalAmount: string;
  currency: string;
}

export interface BillUpdatedPayload {
  billId: string;
  billTitle: string;
  editorId: string;
  editorName: string;
  participantId: string;
  oldAmount: string;
  newAmount: string;
  titleChanged?: { old: string | null; new: string | null };
  totalAmountChanged?: { old: string; new: string };
  reason?: string;
}

export interface BillWrittenOffPayload {
  billId: string;
  billTitle: string;
  actorId: string;
  actorName: string;
  participantId: string;
  oldAmount: string;
  newAmount: string;
  writtenOffAmount: string;
  reason?: string;
}

export interface PaymentPendingConfirmationPayload {
  billId: string;
  billTitle: string;
  paymentId: string;
  participantId: string;
  payerId: string;
  payerName: string;
  amount: string;
  currency: string;
  slipVerified: boolean;
}

export interface PaymentConfirmedPayload {
  billId: string;
  billTitle: string;
  paymentId: string;
  participantId: string;
  payerId: string;
  confirmerId: string;
  confirmerName: string;
  amount: string;
  currency: string;
  installmentNumber: number | null;
  remainingDebt: string;
  isFullyPaid: boolean;
}

export interface PaymentRejectedPayload {
  billId: string;
  billTitle: string;
  paymentId: string;
  participantId: string;
  payerId: string;
  rejecterId: string;
  rejecterName: string;
  amount: string;
  currency: string;
  reason: string;
}

export interface DebtWeeklyReminderPayload {
  billId: string;
  billTitle: string;
  billItemId: string;
  debtorId: string;
  originalDebt: string;
  remainingDebt: string;
  amountPaid: string;
  amountWrittenOff: string;
  currency: string;
  weekKey: string; // e.g. 2026-W34
}

export interface FriendRequestReceivedPayload {
  requestId: string;
  requesterId: string;
  requesterName: string;
  requesterUserCode: string;
}

export interface FriendRequestAcceptedPayload {
  friendshipId: string;
  friendId: string;
  friendName: string;
  friendUserCode: string;
}

export interface BillCancelledPayload {
  billId: string;
  billTitle: string;
  cancellerId: string;
  cancellerName: string;
  participantId?: string;
  reason?: string;
}

export type NotificationPayload =
  | BillCreatedPayload
  | BillUpdatedPayload
  | BillWrittenOffPayload
  | BillCancelledPayload
  | PaymentPendingConfirmationPayload
  | PaymentConfirmedPayload
  | PaymentRejectedPayload
  | DebtWeeklyReminderPayload
  | FriendRequestReceivedPayload
  | FriendRequestAcceptedPayload;

export interface EnqueueNotificationDTO {
  eventType: NotificationEventType;
  recipientUserId: string;
  channel?: "line" | "email" | "sms" | "push";
  payload: NotificationPayload;
  deduplicationKey: string;
  availableAt?: Date;
}
