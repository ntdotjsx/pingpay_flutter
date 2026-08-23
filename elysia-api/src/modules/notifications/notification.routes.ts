import { Elysia, t } from "elysia";
import { defaultNotificationOutboxService } from "./notification-outbox.service";
import { db } from "../../db";
import { deviceTokens } from "../../db/schema";
import { eq } from "drizzle-orm";

export const notificationRoutes = new Elysia({ prefix: "/notifications" })
  .get(
    "/:id",
    async ({ params: { id }, set }) => {
      const notification = await defaultNotificationOutboxService.getNotificationById(id);
      if (!notification) {
        set.status = 404;
        return { error: "NOTIFICATION_NOT_FOUND", message: "Notification record not found." };
      }

      return {
        id: notification.id,
        eventType: notification.eventType,
        recipientUserId: notification.recipientUserId,
        channel: notification.channel,
        payload: notification.payload,
        deduplicationKey: notification.deduplicationKey,
        status: notification.status,
        attempts: notification.attempts,
        maxAttempts: notification.maxAttempts,
        availableAt: notification.availableAt,
        sentAt: notification.sentAt,
        failedAt: notification.failedAt,
        lastError: notification.lastError,
        createdAt: notification.createdAt,
        deliveries: notification.deliveries || [],
      };
    },
    {
      params: t.Object({
        id: t.String(),
      }),
      detail: {
        summary: "5.38 Get Notification Delivery Status & Audit Trail",
        tags: ["Notifications"],
      },
    }
  )
  .get(
    "/user/:userId",
    async ({ params: { userId }, query }) => {
      const limit = query.limit ? parseInt(query.limit, 10) : 20;
      const list = await defaultNotificationOutboxService.getUserNotifications(userId, limit);
      return {
        notifications: list,
      };
    },
    {
      params: t.Object({
        userId: t.String(),
      }),
      query: t.Object({
        limit: t.Optional(t.String()),
      }),
      detail: {
        summary: "Get notifications for a user",
        tags: ["Notifications"],
      },
    }
  )
  .post(
    "/device-token",
    async ({ user, body, set }: any) => {
      const userId = user?.id;
      if (!userId) {
        set.status = 401;
        return { error: "UNAUTHORIZED", message: "User is not authenticated" };
      }

      const { token, platform } = body;

      try {
        const existing = await db.query.deviceTokens.findFirst({
          where: eq(deviceTokens.token, token),
        });

        if (existing) {
          await db
            .update(deviceTokens)
            .set({
              userId,
              platform: platform || existing.platform,
              updatedAt: new Date(),
            })
            .where(eq(deviceTokens.token, token));
        } else {
          await db.insert(deviceTokens).values({
            userId,
            token,
            platform: platform || "android",
          });
        }

        return {
          success: true,
          message: "Device token registered successfully",
        };
      } catch (err: any) {
        console.error("Failed to register device token:", err);
        return {
          success: true,
          message: "Device token processed",
        };
      }
    },
    {
      body: t.Object({
        token: t.String(),
        platform: t.Optional(t.String()),
      }),
      detail: {
        summary: "Register / Update FCM Device Token for Push Notifications",
        tags: ["Notifications"],
      },
    }
  );
