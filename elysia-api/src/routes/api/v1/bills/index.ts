import { Elysia } from "elysia";
import { billRoutes } from "../../../../modules/bills/bill.routes";
import { onboardingGuard } from "../../../../middleware/auth";

export default new Elysia()
  .use(onboardingGuard)
  .use(billRoutes);
