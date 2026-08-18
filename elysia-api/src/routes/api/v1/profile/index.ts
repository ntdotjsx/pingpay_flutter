import { Elysia, t } from "elysia";
import { db } from "../../../../db";
import { users } from "../../../../db/schema";
import { eq } from "drizzle-orm";
import jwt from "jsonwebtoken";
import { env } from "../../../../config/env";

const requireAuth = (app: Elysia) => 
  app.derive(async ({ cookie: { access_token }, headers, set }) => {
    let token = access_token.value;
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader && authHeader.startsWith("Bearer ")) {
      token = authHeader.substring(7);
    }

    if (!token) {
      set.status = 401;
      throw new Error("Unauthorized");
    }
    try {
      const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as { userId: string };
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
    const updateData: any = {
      profileCompletedAt: new Date(),
    };

    if (body.displayName) updateData.displayName = body.displayName;
    if (body.fullName) updateData.fullName = body.fullName;
    if (body.address !== undefined) updateData.address = body.address;
    if (body.phoneNumber !== undefined) updateData.phoneNumber = body.phoneNumber;
    if (body.promptPayId !== undefined) updateData.promptPayId = body.promptPayId;

    const [updatedUser] = await db
      .update(users)
      .set(updateData)
      .where(eq(users.id, userId))
      .returning();

    return {
      success: true,
      user: {
        id: updatedUser.id,
        userCode: updatedUser.userCode,
        displayName: updatedUser.displayName,
        fullName: updatedUser.fullName,
        avatarUrl: updatedUser.avatarUrl,
      },
      profileCompletedAt: updatedUser.profileCompletedAt,
    };
  }, {
    body: t.Object({
      displayName: t.Optional(t.String({ minLength: 1, maxLength: 64 })),
      fullName: t.Optional(t.String({ minLength: 1, maxLength: 128 })),
      address: t.Optional(t.String()),
      phoneNumber: t.Optional(t.String()),
      promptPayId: t.Optional(t.String()),
    }),
    detail: { tags: ["Profile & Consent"], summary: "Update user profile / Set username" }
  });
