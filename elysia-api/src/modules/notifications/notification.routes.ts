import { Elysia, t } from "elysia";
import { defaultNotificationOutboxService } from "./notification-outbox.service";

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
  );
