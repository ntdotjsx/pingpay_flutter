import { t } from "elysia";

export const SearchUserQuerySchema = t.Object({
  userCode: t.String({ minLength: 1, maxLength: 32 }),
});

export const SendFriendRequestSchema = t.Object({
  userCode: t.String({ minLength: 1, maxLength: 32 }),
});

export const PaginationQuerySchema = t.Object({
  limit: t.Optional(t.Numeric({ default: 20, minimum: 1, maximum: 100 })),
  cursor: t.Optional(t.String()),
});

export const RemoveFriendSchema = t.Object({
  confirmOutstandingDebt: t.Optional(t.Boolean({ default: false })),
});

export type RelationshipState =
  | "SELF"
  | "NONE"
  | "OUTGOING_REQUEST"
  | "INCOMING_REQUEST"
  | "FRIEND"
  | "BLOCKED";
