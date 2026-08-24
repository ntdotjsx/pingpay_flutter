import { Elysia, t } from "elysia";
import { db } from "../../../../db";
import { users } from "../../../../db/schema";
import { logActivity } from "../../../../modules/activity/activity.service";
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
      firstName: user.firstName,
      lastName: user.lastName,
      displayName: user.displayName,
      address: user.address,
      phoneNumber: user.phoneNumber,
      bankAccountNumber: user.bankAccountNumber,
      bankName: user.bankName,
      bankCode: user.bankCode,
      truemoneyPhone: user.truemoneyPhone,
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

    if (body.displayName !== undefined) updateData.displayName = body.displayName;
    if (body.fullName !== undefined) updateData.fullName = body.fullName;
    if (body.firstName !== undefined) updateData.firstName = body.firstName;
    if (body.lastName !== undefined) updateData.lastName = body.lastName;

    // If both firstName and lastName are given, combine into fullName if not provided
    if (body.firstName && body.lastName && !body.fullName) {
      updateData.fullName = `${body.firstName.trim()} ${body.lastName.trim()}`;
    }

    if (body.address !== undefined) updateData.address = body.address;
    if (body.phoneNumber !== undefined) updateData.phoneNumber = body.phoneNumber;
    if (body.promptPayId !== undefined) updateData.promptPayId = body.promptPayId;
    if (body.promptPayIdType !== undefined) updateData.promptPayIdType = body.promptPayIdType;
    if (body.bankAccountNumber !== undefined) updateData.bankAccountNumber = body.bankAccountNumber;
    if (body.bankName !== undefined) updateData.bankName = body.bankName;
    if (body.bankCode !== undefined) updateData.bankCode = body.bankCode;
    if (body.truemoneyPhone !== undefined) updateData.truemoneyPhone = body.truemoneyPhone;
    if (body.shippingAddress !== undefined) updateData.shippingAddress = body.shippingAddress;
    if (body.shippingPhone !== undefined) updateData.shippingPhone = body.shippingPhone;
    if (body.shippingRecipientName !== undefined) updateData.shippingRecipientName = body.shippingRecipientName;

    const [updatedUser] = await db
      .update(users)
      .set(updateData)
      .where(eq(users.id, userId))
      .returning();

    logActivity(userId, "profile_updated", {
      hasPromptPay: !!updatedUser.promptPayId,
      hasBank: !!updatedUser.bankAccountNumber,
      hasTrueMoney: !!updatedUser.truemoneyPhone,
      hasShipping: !!updatedUser.shippingAddress,
    });

    return {
      success: true,
      message: "Profile updated successfully",
      profile: {
        displayName: updatedUser.displayName,
        fullName: updatedUser.fullName,
        firstName: updatedUser.firstName,
        lastName: updatedUser.lastName,
        address: updatedUser.address,
        phoneNumber: updatedUser.phoneNumber,
        promptPayId: updatedUser.promptPayId,
        promptPayIdType: updatedUser.promptPayIdType,
        bankAccountNumber: updatedUser.bankAccountNumber,
        bankName: updatedUser.bankName,
        bankCode: updatedUser.bankCode,
        truemoneyPhone: updatedUser.truemoneyPhone,
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
      firstName: t.Optional(t.String()),
      lastName: t.Optional(t.String()),
      address: t.Optional(t.String()),
      phoneNumber: t.Optional(t.String()),
      promptPayId: t.Optional(t.String()),
      promptPayIdType: t.Optional(t.String()),
      bankAccountNumber: t.Optional(t.String()),
      bankName: t.Optional(t.String()),
      bankCode: t.Optional(t.String()),
      truemoneyPhone: t.Optional(t.String()),
      shippingAddress: t.Optional(t.String()),
      shippingPhone: t.Optional(t.String()),
      shippingRecipientName: t.Optional(t.String()),
    }),
    detail: { tags: ["Profile & Consent"], summary: "Save user profile" }
  })
  .post("/test-fcm-notification", async ({ userId, set }) => {
    try {
      const user = await db.query.users.findFirst({
        where: eq(users.id, userId)
      });

      if (!user) {
        set.status = 404;
        return { success: false, error: "User not found" };
      }

      const { defaultFcmNotificationProvider } = await import("../../../../modules/notifications/fcm-notification.provider");
      
      const sendResult = await defaultFcmNotificationProvider.send(
        userId,
        null,
        {
          title: "🔔 PingPay ข้อความทดสอบ",
          body: `สวัสดีคุณ ${user.displayName || user.fullName || "ผู้ใช้งาน"}!\n\n🎉 การเชื่อมต่อ Firebase Cloud Messaging กับ PingPay สำเร็จเรียบร้อยแล้ว!\nระบบพร้อมส่งการแจ้งเตือนบิลและการชำระเงินให้คุณแบบ Real-time ✨`,
          data: { test: true }
        }
      );

      if (!sendResult.success) {
        set.status = 400;
        return {
          success: false,
          error: sendResult.error || sendResult.skippedReason || "FCM_SEND_FAILED: ยังไม่พบ Device Token ที่ลงทะเบียนไว้",
        };
      }

      return {
        success: true,
        message: "ส่งข้อความแจ้งเตือนเข้า Firebase Cloud Messaging (FCM) สำเร็จแล้ว!",
      };
    } catch (e: any) {
      set.status = 500;
      return { success: false, error: e.message };
    }
  }, {
    detail: { tags: ["Profile & Consent"], summary: "Send Test FCM Push Notification" }
  })
  .post("/test-line-notification", async ({ userId, set }) => {
    // Backward compatibility alias routing to FCM
    const { defaultFcmNotificationProvider } = await import("../../../../modules/notifications/fcm-notification.provider");
    const sendResult = await defaultFcmNotificationProvider.send(
      userId,
      null,
      {
        title: "🔔 PingPay ข้อความทดสอบ",
        body: "ทดสอบการส่งการแจ้งเตือนผ่าน Firebase Cloud Messaging สำเร็จเรียบร้อยแล้ว!",
        data: { test: true }
      }
    );
    return {
      success: sendResult.success,
      message: sendResult.success ? "ส่งการแจ้งเตือน FCM สำเร็จแล้ว!" : (sendResult.skippedReason || "ส่งการแจ้งเตือนไม่สำเร็จ"),
    };
  });
