import { db } from "../../db";
import { users, friendships, editLogs, accountStatusEnum } from "../../db/schema";
import { eq, or, and, desc, isNull, ne } from "drizzle-orm";
import type { RelationshipState } from "./friend.types";
import { DebtRelationshipService } from "../debt/debt-relationship.service";
import { defaultNotificationOutboxService } from "../notifications/notification-outbox.service";
import { realtimeService } from "../../realtime/realtime.service";

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

    // We will do an explicit check and insert/update using a transaction.
    const request = await db.transaction(async (tx) => {
      // Check for any existing record between these two users (including previous cancelled/rejected/removed)
      const existing = await tx
        .select()
        .from(friendships)
        .where(
          or(
            and(eq(friendships.requesterId, currentUserId), eq(friendships.addresseeId, target.id)),
            and(eq(friendships.requesterId, target.id), eq(friendships.addresseeId, currentUserId))
          )
        );

      const activeRecord = existing.find(
        (r) => r.removedAt === null && (r.status === "accepted" || r.status === "pending" || r.status === "blocked")
      );

      if (activeRecord) {
        if (activeRecord.status === "accepted") throw new Error("ALREADY_FRIENDS");
        if (activeRecord.status === "pending") {
          if (activeRecord.requesterId === currentUserId) throw new Error("FRIEND_REQUEST_ALREADY_SENT");
          throw new Error("INCOMING_FRIEND_REQUEST_EXISTS");
        }
        if (activeRecord.status === "blocked") throw new Error("USER_UNAVAILABLE");
      }

      let newRequest: any;

      if (existing.length > 0) {
        // Reuse and update the existing friendship record back to pending
        const [updated] = await tx
          .update(friendships)
          .set({
            requesterId: currentUserId,
            addresseeId: target.id,
            status: "pending",
            createdAt: new Date(),
            respondedAt: null,
            removedAt: null,
          })
          .where(eq(friendships.id, existing[0].id))
          .returning();
        newRequest = updated;
      } else {
        const [inserted] = await tx
          .insert(friendships)
          .values({
            requesterId: currentUserId,
            addresseeId: target.id,
            status: "pending",
          })
          .returning();
        newRequest = inserted;
      }

      // Enqueue friend request notification for addressee
      const requester = await tx.query.users.findFirst({
        where: eq(users.id, currentUserId),
      });

      if (requester) {
        await defaultNotificationOutboxService.enqueueInTx(tx, {
          eventType: "FRIEND_REQUEST_RECEIVED",
          recipientUserId: target.id,
          deduplicationKey: `FRIEND_REQUEST_RECEIVED:${newRequest.id}:${target.id}:${Date.now()}`,
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

    realtimeService.sendToUser(target.id, realtimeService.makeEvent(
      "friend.request.created",
      {
        requestId: request.id,
        senderId: currentUserId,
        receiverId: target.id,
      },
      { resourceId: request.id }
    ));
    console.log(`[Realtime] Friend request event sent requestId=${request.id} receiverId=${target.id}`);

    return request;
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
    const friendship = await db.transaction(async (tx) => {
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
        action: "friend_added",
        performedById: currentUserId,
        affectedUserId: request.requesterId,
        note: `friendshipId:${updated.id}`,
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

    realtimeService.sendToUsers(
      [friendship.requesterId, friendship.addresseeId],
      realtimeService.makeEvent(
        "friend.request.accepted",
        {
          requestId,
          friendshipId: friendship.id,
          requesterId: friendship.requesterId,
          addresseeId: friendship.addresseeId,
          acceptedBy: currentUserId,
        },
        { resourceId: friendship.id }
      )
    );
    console.log(`[Realtime] Friend accepted event sent friendshipId=${friendship.id}`);

    return friendship;
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

    realtimeService.sendToUsers(
      [request.requesterId, request.addresseeId],
      realtimeService.makeEvent(
        "friend.request.rejected",
        {
          requestId: updated.id,
          requesterId: request.requesterId,
          addresseeId: request.addresseeId,
          rejectedBy: currentUserId,
        },
        { resourceId: updated.id }
      )
    );
    console.log(`[Realtime] Friend rejected event sent requestId=${updated.id}`);

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

    realtimeService.sendToUsers(
      [request.requesterId, request.addresseeId],
      realtimeService.makeEvent(
        "friend.request.cancelled",
        {
          requestId: updated.id,
          requesterId: request.requesterId,
          addresseeId: request.addresseeId,
          cancelledBy: currentUserId,
        },
        { resourceId: updated.id }
      )
    );
    console.log(`[Realtime] Friend cancelled event sent requestId=${updated.id}`);

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
        canRemove: false,
        requiresExplicitDebtConfirmation: true,
        outstanding: {
          youOweFriend: debt.userAOwesUserB,
          friendOwesYou: debt.userBOwesUserA,
        },
        warning: {
          code: "OUTSTANDING_DEBT_EXISTS",
          message: "ไม่สามารถลบเพื่อนได้เนื่องจากยังมียอดเงินค้างชำระระหว่างกัน กรุณาเคลียร์ยอดเงินให้ครบถ้วนก่อน",
        },
      };
    }

    return {
      hasOutstandingDebt: false,
      canRemove: true,
      requiresExplicitDebtConfirmation: false,
    };
  }

  static async removeFriend(friendshipId: string, currentUserId: string, confirmOutstandingDebt: boolean = false) {
    const removed = await db.transaction(async (tx) => {
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

      if (debt.hasOutstandingDebt) {
        throw new Error("CANNOT_REMOVE_FRIEND_WITH_OUTSTANDING_DEBT: ไม่สามารถลบเพื่อนได้เนื่องจากยังมียอดหนี้ค้างชำระระหว่างกัน กรุณาเคลียร์ยอดเงินให้ครบถ้วนก่อน");
      }

      const [updated] = await tx
        .update(friendships)
        .set({
          removedAt: new Date(),
        })
        .where(eq(friendships.id, friendshipId))
        .returning();

      await tx.insert(editLogs).values({
        action: "friend_removed",
        performedById: currentUserId,
        affectedUserId: friendId,
        note: `friendshipId:${updated.id}`,
      });

      return updated;
    });

    realtimeService.sendToUsers(
      [removed.requesterId, removed.addresseeId],
      realtimeService.makeEvent(
        "friend.removed",
        {
          friendshipId: removed.id,
          requesterId: removed.requesterId,
          addresseeId: removed.addresseeId,
          removedBy: currentUserId,
        },
        { resourceId: removed.id }
      )
    );
    console.log(`[Realtime] Friend removed event sent friendshipId=${removed.id}`);

    return removed;
  }
}
