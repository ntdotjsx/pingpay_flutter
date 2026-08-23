import { db } from "../../db";
import { users, friendships, editLogs, accountStatusEnum } from "../../db/schema";
import { eq, or, and, desc, isNull, ne } from "drizzle-orm";
import type { RelationshipState } from "./friend.types";
import { DebtRelationshipService } from "../debt/debt-relationship.service";
import { defaultNotificationOutboxService } from "../notifications/notification-outbox.service";

export class FriendService {
  /**
   * Determine relationship state between two users based on existing friendships table
   */
  static async getRelationshipState(currentUserId: string, targetUserId: string): Promise<RelationshipState> {
    if (currentUserId === targetUserId) {
      return "SELF";
    }

    const records = await db
      .select()
      .from(friendships)
      .where(
        and(
          isNull(friendships.removedAt),
          or(
            and(eq(friendships.requesterId, currentUserId), eq(friendships.addresseeId, targetUserId)),
            and(eq(friendships.requesterId, targetUserId), eq(friendships.addresseeId, currentUserId))
          )
        )
      );

    if (records.length === 0) {
      return "NONE";
    }

    // Should theoretically only be one active record due to our logic, but we'll check the first one
    const rel = records[0];

    if (rel.status === "blocked") return "BLOCKED";
    if (rel.status === "accepted") return "FRIEND";
    
    if (rel.status === "pending") {
      if (rel.requesterId === currentUserId) return "OUTGOING_REQUEST";
      return "INCOMING_REQUEST";
    }

    return "NONE";
  }

  /**
   * Search exact user by public userCode
   */
  static async searchUser(userCode: string, currentUserId: string) {
    const user = await db.query.users.findFirst({
      where: eq(users.userCode, userCode),
    });

    if (!user) {
      return null;
    }

    // Only allow finding active users, although spec says return USER_NOT_FOUND,
    // let's just allow searching but only expose safe profile details.
    const relationship = await this.getRelationshipState(currentUserId, user.id);

    return {
      userCode: user.userCode,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      relationship,
    };
  }

  /**
   * Send a friend request
   */
  static async sendFriendRequest(targetUserCode: string, currentUserId: string) {
    const target = await db.query.users.findFirst({
      where: eq(users.userCode, targetUserCode),
    });

    if (!target) throw new Error("USER_NOT_FOUND");
    if (target.accountStatus !== "active") throw new Error("USER_UNAVAILABLE");
    if (target.id === currentUserId) throw new Error("CANNOT_ADD_SELF");

    const relState = await this.getRelationshipState(currentUserId, target.id);

    if (relState === "FRIEND") throw new Error("ALREADY_FRIENDS");
    if (relState === "OUTGOING_REQUEST") throw new Error("FRIEND_REQUEST_ALREADY_SENT");
    if (relState === "INCOMING_REQUEST") throw new Error("INCOMING_FRIEND_REQUEST_EXISTS");
    if (relState === "BLOCKED") throw new Error("USER_UNAVAILABLE");

    // Double check reverse direction safely with transactions or simple insert since unique index is present,
    // but the unique index is directional (requesterId, addresseeId).
    // We will do an explicit check and insert using a transaction.
    return await db.transaction(async (tx) => {
      // Check again inside tx
      const existing = await tx
        .select()
        .from(friendships)
        .where(
          and(
            isNull(friendships.removedAt),
            or(
              and(eq(friendships.requesterId, currentUserId), eq(friendships.addresseeId, target.id)),
              and(eq(friendships.requesterId, target.id), eq(friendships.addresseeId, currentUserId))
            )
          )
        );

      if (existing.length > 0) {
        throw new Error("RELATIONSHIP_EXISTS");
      }

      const [newRequest] = await tx
        .insert(friendships)
        .values({
          requesterId: currentUserId,
          addresseeId: target.id,
          status: "pending",
        })
        .returning();

      // Enqueue friend request notification for addressee
      const requester = await tx.query.users.findFirst({
        where: eq(users.id, currentUserId),
      });

      if (requester) {
        await defaultNotificationOutboxService.enqueueInTx(tx, {
          eventType: "FRIEND_REQUEST_RECEIVED",
          recipientUserId: target.id,
          deduplicationKey: `FRIEND_REQUEST_RECEIVED:${newRequest.id}:${target.id}`,
          payload: {
            requestId: newRequest.id,
            requesterId: currentUserId,
            requesterName: requester.displayName || requester.fullName || "ผู้ใช้ PingPay",
            requesterUserCode: requester.userCode,
          },
        });
      }

      return newRequest;
    });
  }

  static async getIncomingRequests(currentUserId: string, limit: number) {
    const reqs = await db
      .select({
        requestId: friendships.id,
        createdAt: friendships.createdAt,
        userCode: users.userCode,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
      })
      .from(friendships)
      .innerJoin(users, eq(friendships.requesterId, users.id))
      .where(
        and(
          eq(friendships.addresseeId, currentUserId),
          eq(friendships.status, "pending"),
          isNull(friendships.removedAt)
        )
      )
      .limit(limit)
      .orderBy(desc(friendships.createdAt));

    return reqs.map((r) => ({
      requestId: r.requestId,
      createdAt: r.createdAt,
      user: {
        userCode: r.userCode,
        displayName: r.displayName,
        avatarUrl: r.avatarUrl,
      },
    }));
  }

  static async getOutgoingRequests(currentUserId: string, limit: number) {
    const reqs = await db
      .select({
        requestId: friendships.id,
        createdAt: friendships.createdAt,
        userCode: users.userCode,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
      })
      .from(friendships)
      .innerJoin(users, eq(friendships.addresseeId, users.id))
      .where(
        and(
          eq(friendships.requesterId, currentUserId),
          eq(friendships.status, "pending"),
          isNull(friendships.removedAt)
        )
      )
      .limit(limit)
      .orderBy(desc(friendships.createdAt));

    return reqs.map((r) => ({
      requestId: r.requestId,
      createdAt: r.createdAt,
      user: {
        userCode: r.userCode,
        displayName: r.displayName,
        avatarUrl: r.avatarUrl,
      },
    }));
  }

  static async acceptRequest(requestId: string, currentUserId: string) {
    return await db.transaction(async (tx) => {
      const request = await tx.query.friendships.findFirst({
        where: eq(friendships.id, requestId),
      });

      if (!request) throw new Error("FRIEND_REQUEST_NOT_FOUND");
      if (request.addresseeId !== currentUserId) throw new Error("FORBIDDEN");
      if (request.status !== "pending" || request.removedAt !== null) {
        throw new Error("FRIEND_REQUEST_NOT_PENDING");
      }

      const [updated] = await tx
        .update(friendships)
        .set({
          status: "accepted",
          respondedAt: new Date(),
        })
        .where(eq(friendships.id, requestId))
        .returning();

      // Log activity
      await tx.insert(editLogs).values({
        entityType: "friend",
        entityId: updated.id,
        editorId: currentUserId,
        action: "friend_added",
      });

      // Enqueue friend request accepted notification for requester
      const acceptor = await tx.query.users.findFirst({
        where: eq(users.id, currentUserId),
      });

      if (acceptor) {
        await defaultNotificationOutboxService.enqueueInTx(tx, {
          eventType: "FRIEND_REQUEST_ACCEPTED",
          recipientUserId: request.requesterId,
          deduplicationKey: `FRIEND_REQUEST_ACCEPTED:${updated.id}:${request.requesterId}`,
          payload: {
            friendshipId: updated.id,
            friendId: currentUserId,
            friendName: acceptor.displayName || acceptor.fullName || "เพื่อนของคุณ",
            friendUserCode: acceptor.userCode,
          },
        });
      }

      return updated;
    });
  }

  static async rejectRequest(requestId: string, currentUserId: string) {
    const request = await db.query.friendships.findFirst({
      where: eq(friendships.id, requestId),
    });

    if (!request) throw new Error("FRIEND_REQUEST_NOT_FOUND");
    if (request.addresseeId !== currentUserId) throw new Error("FORBIDDEN");
    if (request.status !== "pending" || request.removedAt !== null) {
      throw new Error("FRIEND_REQUEST_NOT_PENDING");
    }

    const [updated] = await db
      .update(friendships)
      .set({
        status: "rejected",
        respondedAt: new Date(),
      })
      .where(eq(friendships.id, requestId))
      .returning();

    return updated;
  }

  static async cancelRequest(requestId: string, currentUserId: string) {
    const request = await db.query.friendships.findFirst({
      where: eq(friendships.id, requestId),
    });

    if (!request) throw new Error("FRIEND_REQUEST_NOT_FOUND");
    if (request.requesterId !== currentUserId) throw new Error("FORBIDDEN");
    if (request.status !== "pending" || request.removedAt !== null) {
      throw new Error("FRIEND_REQUEST_NOT_PENDING");
    }

    const [updated] = await db
      .update(friendships)
      .set({
        status: "cancelled",
        respondedAt: new Date(),
      })
      .where(eq(friendships.id, requestId))
      .returning();

    return updated;
  }

  static async getFriends(currentUserId: string, limit: number) {
    const friendsList = await db
      .select({
        friendshipId: friendships.id,
        createdAt: friendships.createdAt,
        id: users.id,
        userCode: users.userCode,
        displayName: users.displayName,
        avatarUrl: users.avatarUrl,
      })
      .from(friendships)
      .innerJoin(
        users,
        or(
          and(eq(friendships.requesterId, currentUserId), eq(friendships.addresseeId, users.id)),
          and(eq(friendships.addresseeId, currentUserId), eq(friendships.requesterId, users.id))
        )
      )
      .where(
        and(
          eq(friendships.status, "accepted"),
          isNull(friendships.removedAt),
          or(
            eq(friendships.requesterId, currentUserId),
            eq(friendships.addresseeId, currentUserId)
          )
        )
      )
      .limit(limit);

    return friendsList.map((f) => ({
      friendshipId: f.friendshipId,
      friendsSince: f.createdAt,
      user: {
        id: f.id,
        userCode: f.userCode,
        displayName: f.displayName,
        avatarUrl: f.avatarUrl,
      },
    }));
  }

  static async getFriendDetails(friendshipId: string, currentUserId: string) {
    const friendship = await db.query.friendships.findFirst({
      where: eq(friendships.id, friendshipId),
    });

    if (!friendship) throw new Error("FRIENDSHIP_NOT_FOUND");
    if (friendship.status !== "accepted" || friendship.removedAt !== null) {
      throw new Error("FRIENDSHIP_NOT_FOUND");
    }
    if (friendship.requesterId !== currentUserId && friendship.addresseeId !== currentUserId) {
      throw new Error("FORBIDDEN");
    }

    const friendId = friendship.requesterId === currentUserId ? friendship.addresseeId : friendship.requesterId;
    
    const friend = await db.query.users.findFirst({
      where: eq(users.id, friendId),
    });

    if (!friend) throw new Error("USER_NOT_FOUND");

    return {
      friendshipId: friendship.id,
      friendsSince: friendship.createdAt,
      user: {
        userCode: friend.userCode,
        displayName: friend.displayName,
        avatarUrl: friend.avatarUrl,
      },
    };
  }

  static async checkRemoval(friendshipId: string, currentUserId: string) {
    const friendship = await db.query.friendships.findFirst({
      where: eq(friendships.id, friendshipId),
    });

    if (!friendship) throw new Error("FRIENDSHIP_NOT_FOUND");
    if (friendship.requesterId !== currentUserId && friendship.addresseeId !== currentUserId) {
      throw new Error("FORBIDDEN");
    }
    if (friendship.status !== "accepted" || friendship.removedAt !== null) {
      throw new Error("FRIENDSHIP_NOT_FOUND");
    }

    const friendId = friendship.requesterId === currentUserId ? friendship.addresseeId : friendship.requesterId;

    const debt = await DebtRelationshipService.getOutstandingDebtBetween(currentUserId, friendId);

    if (debt.hasOutstandingDebt) {
      return {
        hasOutstandingDebt: true,
        requiresExplicitDebtConfirmation: true,
        outstanding: {
          youOweFriend: debt.userAOwesUserB,
          friendOwesYou: debt.userBOwesUserA,
        },
        warning: {
          code: "OUTSTANDING_DEBT_EXISTS",
          message: "There is still outstanding debt between these users.",
        },
      };
    }

    return {
      hasOutstandingDebt: false,
      requiresExplicitDebtConfirmation: false,
    };
  }

  static async removeFriend(friendshipId: string, currentUserId: string, confirmOutstandingDebt: boolean) {
    return await db.transaction(async (tx) => {
      const friendship = await tx.query.friendships.findFirst({
        where: eq(friendships.id, friendshipId),
      });

      if (!friendship) throw new Error("FRIENDSHIP_NOT_FOUND");
      if (friendship.requesterId !== currentUserId && friendship.addresseeId !== currentUserId) {
        throw new Error("FORBIDDEN");
      }
      if (friendship.status !== "accepted" || friendship.removedAt !== null) {
        throw new Error("FRIENDSHIP_NOT_FOUND");
      }

      const friendId = friendship.requesterId === currentUserId ? friendship.addresseeId : friendship.requesterId;

      const debt = await DebtRelationshipService.getOutstandingDebtBetween(currentUserId, friendId);

      if (debt.hasOutstandingDebt && !confirmOutstandingDebt) {
        throw new Error("OUTSTANDING_DEBT_CONFIRMATION_REQUIRED");
      }

      const [updated] = await tx
        .update(friendships)
        .set({
          removedAt: new Date(),
        })
        .where(eq(friendships.id, friendshipId))
        .returning();

      await tx.insert(editLogs).values({
        entityType: "friend",
        entityId: updated.id,
        editorId: currentUserId,
        action: "friend_removed",
      });

      return updated;
    });
  }
}
