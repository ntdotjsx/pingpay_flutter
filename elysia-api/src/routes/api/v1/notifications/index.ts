import { Elysia } from "elysia";
import { notificationRoutes } from "../../../../modules/notifications/notification.routes";
import { onboardingGuard } from "../../../../middleware/auth";

export default new Elysia()
  .use(onboardingGuard)
  .use(notificationRoutes);
