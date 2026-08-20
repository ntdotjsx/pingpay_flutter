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
      rewardPoints: user.rewardPoints ?? 27,
      shippingAddress: user.shippingAddress,
      shippingPhone: user.shippingPhone,
      shippingRecipientName: user.shippingRecipientName,
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
    if (body.promptPayIdType !== undefined) updateData.promptPayIdType = body.promptPayIdType;
    if (body.bankAccountNumber !== undefined) updateData.bankAccountNumber = body.bankAccountNumber;
    if (body.shippingAddress !== undefined) updateData.shippingAddress = body.shippingAddress;
    if (body.shippingPhone !== undefined) updateData.shippingPhone = body.shippingPhone;
    if (body.shippingRecipientName !== undefined) updateData.shippingRecipientName = body.shippingRecipientName;

    const [updatedUser] = await db
      .update(users)
      .set(updateData)
      .where(eq(users.id, userId))
      .returning();

    return {
      success: true,
      message: "Profile updated successfully",
      profile: {
        displayName: updatedUser.displayName,
        fullName: updatedUser.fullName,
        address: updatedUser.address,
        phoneNumber: updatedUser.phoneNumber,
        promptPayId: updatedUser.promptPayId,
        promptPayIdType: updatedUser.promptPayIdType,
        bankAccountNumber: updatedUser.bankAccountNumber,
        rewardPoints: updatedUser.rewardPoints,
        shippingAddress: updatedUser.shippingAddress,
        shippingPhone: updatedUser.shippingPhone,
        shippingRecipientName: updatedUser.shippingRecipientName,
      }
    };
  }, {
    body: t.Object({
      displayName: t.Optional(t.String()),
      fullName: t.Optional(t.String()),
      address: t.Optional(t.String()),
      phoneNumber: t.Optional(t.String()),
      promptPayId: t.Optional(t.String()),
      promptPayIdType: t.Optional(t.String()),
      bankAccountNumber: t.Optional(t.String()),
      shippingAddress: t.Optional(t.String()),
      shippingPhone: t.Optional(t.String()),
      shippingRecipientName: t.Optional(t.String()),
    }),
    detail: { tags: ["Profile & Consent"], summary: "Save user profile" }
  })
  .post("/test-line-notification", async ({ userId, set }) => {
    try {
      const user = await db.query.users.findFirst({
        where: eq(users.id, userId)
      });

      if (!user) {
        set.status = 404;
        return { success: false, error: "User not found" };
      }

      // Look up linked LINE identity
      const identity = await db.query.authIdentities.findFirst({
        where: (ai, { and, eq }) => and(eq(ai.userId, userId), eq(ai.provider, "line"))
      });

      const targetLineId = identity?.providerUserId;

      if (!targetLineId) {
        set.status = 400;
        return {
          success: false,
          error: "NO_LINE_ACCOUNT: บัญชีนี้ยังไม่ได้ผูกกับ LINE ID หรือไม่ได้เข้าสู่ระบบผ่าน LINE",
        };
      }

      const { defaultLineNotificationProvider } = await import("../../../../modules/notifications/line-notification.provider");
      
      const sendResult = await defaultLineNotificationProvider.send(
        userId,
        targetLineId,
        {
          title: "🔔 PingPay ข้อความทดสอบ",
          body: `สวัสดีคุณ ${user.displayName || user.fullName || "ผู้ใช้งาน"}!\n\n🎉 การเชื่อมต่อ LINE Messaging API กับ PingPay สำเร็จเรียบร้อยแล้ว!\nระบบพร้อมส่งการแจ้งเตือนบิลและการชำระเงินให้คุณแบบ Real-time ✨`,
          data: { test: true }
        }
      );

      if (!sendResult.success) {
        set.status = 400;
        let userFriendlyError = sendResult.error || "LINE_SEND_FAILED";
        if (userFriendlyError.includes("Failed to send messages")) {
          userFriendlyError = "กรุณาเพิ่มเพื่อน LINE Bot (@986qgvvz - น้องปิง) ก่อนทดสอบส่งข้อความ (LINE ไม่อนุญาตให้ Bot ส่งข้อความถึงผู้ใช้ที่ยังไม่ได้เพิ่มเพื่อน)";
        }
        return {
          success: false,
          error: userFriendlyError,
        };
      }

      return {
        success: true,
        message: `ส่งข้อความแจ้งเตือนเข้า LINE (${targetLineId}) สำเร็จแล้ว!`,
        lineUserId: targetLineId,
      };
    } catch (e: any) {
      set.status = 500;
      return { success: false, error: e.message };
    }
  }, {
    detail: { tags: ["Profile & Consent"], summary: "Send Test LINE Push Notification" }
  });
