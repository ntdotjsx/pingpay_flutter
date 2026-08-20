import { Elysia } from "elysia";
import { authGuard } from "./auth";
import { db } from "../db";
import { users } from "../db/schema";
import { eq } from "drizzle-orm";

export const adminGuard = (app: Elysia) =>
  app
    .use(authGuard)
    .derive(async ({ userId }) => {
      if (!userId) {
        return { adminUser: null as any, adminError: "Unauthorized" };
      }

      const user = await db.query.users.findFirst({
        where: eq(users.id, userId),
      });

      if (!user) {
        return { adminUser: null as any, adminError: "User not found" };
      }

      if (user.role !== "developer") {
        return { adminUser: null as any, adminError: "Forbidden: Developer role required" };
      }

      if (user.accountStatus !== "active") {
        return { adminUser: null as any, adminError: "Account is not active" };
      }

      return { adminUser: user, adminError: null };
    })
    .onBeforeHandle(({ adminError, set }) => {
      if (adminError) {
        if (adminError.includes("Forbidden")) {
          set.status = 403;
        } else if (adminError.includes("not found")) {
          set.status = 404;
        } else {
          set.status = 401;
        }
        throw new Error(adminError);
      }
    });
