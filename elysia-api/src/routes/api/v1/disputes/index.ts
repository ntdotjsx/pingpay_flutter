import { Elysia } from "elysia";
import { disputeRoutes } from "../../../../modules/disputes/dispute.routes";
import { onboardingGuard } from "../../../../middleware/auth";

export default new Elysia()
  .use(onboardingGuard)
  .use(disputeRoutes);
