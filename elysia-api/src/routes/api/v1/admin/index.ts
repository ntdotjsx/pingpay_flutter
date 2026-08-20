import { Elysia } from "elysia";
import { adminRoutes } from "../../../../modules/admin/admin.routes";
import { adminGuard } from "../../../../middleware/admin-guard";

export default new Elysia()
  .use(adminGuard)
  .use(adminRoutes);
