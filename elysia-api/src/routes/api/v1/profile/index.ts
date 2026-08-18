import { Elysia, t } from "elysia";
import { db } from "../../../../db";
import { users } from "../../../../db/schema";
import { eq } from "drizzle-orm";
import jwt from "jsonwebtoken";
import { env } from "../../../../config/env";

const requireAuth = (app: Elysia) => 
  app.derive(async ({ cookie: { access_token }, set }) => {
    if (!access_token.value) {
      set.status = 401;
      throw new Error("Unauthorized");
    }
    try {
      const decoded = jwt.verify(access_token.value, env.JWT_ACCESS_SECRET) as { userId: string };
      return { userId: decoded.userId };
    } catch {
      set.status = 401;
      throw new Error("Unauthorized");
    }
  });

export default new Elysia()
  .use(requireAuth)
  .get("/", async ({ userId, set }) => {
    const user = await db.query.users.findFirst({
      where: eq(users.id, userId)
    });

    if (!user) {
      set.status = 404;
      return { error: "User not found" };
    }

    return {
      fullName: user.fullName,
      address: user.address,
      phoneNumber: user.phoneNumber,
      bankAccountNumber: user.bankAccountNumber,
      promptPayId: user.promptPayId,
      promptPayIdType: user.promptPayIdType,
      profileCompletedAt: user.profileCompletedAt,
    };
  }, { detail: { tags: ["Profile & Consent"], summary: "Get user profile" } })
  .post("/", async ({ userId, body }) => {
    const updateData = {
      fullName: body.fullName,
      address: body.address,
      phoneNumber: body.phoneNumber,
      profileCompletedAt: new Date(),
    };

    const [updatedUser] = await db
      .update(users)
      .set(updateData)
      .where(eq(users.id, userId))
      .returning();

    return {
      success: true,
      profileCompletedAt: updatedUser.profileCompletedAt,
    };
  }, {
    body: t.Object({
      fullName: t.String({ minLength: 1 }),
      address: t.String(),
      phoneNumber: t.String({ minLength: 9 }),
    }),
    detail: { tags: ["Profile & Consent"], summary: "Update user profile" }
  });
