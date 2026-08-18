import { Elysia } from "elysia";
import { paymentRoutes } from "../../../../modules/payments/payment.routes";
import { onboardingGuard } from "../../../../middleware/auth";

export default new Elysia()
  .use(onboardingGuard)
  .use(paymentRoutes);
