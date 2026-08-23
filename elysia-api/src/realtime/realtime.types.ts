export type RealtimeEventType =
  | "connection.ready"
  | "sync.required"
  | "friend.request.created"
  | "friend.request.accepted"
  | "friend.request.rejected"
  | "friend.request.cancelled"
  | "friend.removed"
  | "friend.blocked"
  | "friend.unblocked"
  | "bill.created"
  | "bill.updated"
  | "bill.deleted"
  | "bill.member.added"
  | "bill.member.removed"
  | "bill.transaction.created"
  | "bill.transaction.updated"
  | "bill.transaction.deleted"
  | "bill.payment.updated"
  | "bill.status.updated"
  | "notification.created";

export interface RealtimeEvent<TData = Record<string, unknown>> {
  type: RealtimeEventType;
  eventId: string;
  timestamp: string;
  resourceId?: string;
  version?: number;
  data: TData;
}

export type RealtimeSocket = {
  id?: string;
  send: (message: string) => unknown;
  close?: (code?: number, reason?: string) => unknown;
};

export function createRealtimeEvent<TData = Record<string, unknown>>(
  type: RealtimeEventType,
  data: TData,
  options: { resourceId?: string; version?: number; eventId?: string } = {}
): RealtimeEvent<TData> {
  return {
    type,
    eventId: options.eventId ?? crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    resourceId: options.resourceId,
    version: options.version ?? 1,
    data,
  };
}
