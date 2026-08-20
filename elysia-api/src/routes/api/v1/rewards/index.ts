import { Elysia, t } from "elysia";
import { onboardingGuard } from "../../../../middleware/auth";
import { db } from "../../../../db";
import { rewardItems, rewardRedemptions, users } from "../../../../db/schema";
import { eq, desc } from "drizzle-orm";

export default new Elysia()
  .use(onboardingGuard)
  .onBeforeHandle(({ onboardingState, set }) => {
    if (onboardingState !== "COMPLETED") {
      set.status = 403;
      return { error: "Profile not completed. Cannot access reward store." };
    }
  })
  
  // 1. Get Reward Catalog Items
  .get("/items", async ({ set }) => {
    try {
      const items = await db.query.rewardItems.findMany({
        where: eq(rewardItems.isActive, true),
        orderBy: [desc(rewardItems.createdAt)],
      });
      return { success: true, data: { items } };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    detail: {
      tags: ["Rewards"],
      summary: "Get reward catalog items",
      description: "Lists all active redeemable reward gifts and vouchers.",
    }
  })

  // 2. Get Current User Points & Saved Shipping Address
  .get("/points", async ({ user, set }) => {
    try {
      const u = await db.query.users.findFirst({
        where: eq(users.id, user.id),
      });

      if (!u) {
        set.status = 404;
        return { success: false, error: "User not found" };
      }

      return {
        success: true,
        data: {
          rewardPoints: u.rewardPoints ?? 27,
          shippingAddress: u.shippingAddress,
          shippingPhone: u.shippingPhone || u.phoneNumber,
          shippingRecipientName: u.shippingRecipientName || u.fullName || u.displayName,
        }
      };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    detail: {
      tags: ["Rewards"],
      summary: "Get user reward points & default shipping address",
      description: "Returns points balance and saved shipping information.",
    }
  })

  // 3. Redeem a Reward Item (with shipping address)
  .post("/redeem", async ({ user, body, set }) => {
    try {
      const u = await db.query.users.findFirst({
        where: eq(users.id, user.id),
      });

      if (!u) {
        set.status = 404;
        return { success: false, error: "User not found" };
      }

      const item = await db.query.rewardItems.findFirst({
        where: eq(rewardItems.id, body.rewardItemId),
      });

      if (!item || !item.isActive) {
        set.status = 404;
        return { success: false, error: "REWARD_NOT_FOUND: ของรางวัลนี้ไม่มีอยู่ในระบบหรือไม่พร้อมใช้งาน" };
      }

      if (item.inStock <= 0) {
        set.status = 400;
        return { success: false, error: "OUT_OF_STOCK: ขออภัย สินค้าชิ้นนี้หมดแล้ว" };
      }

      const userPoints = u.rewardPoints ?? 0;
      if (userPoints < item.pointsCost) {
        set.status = 400;
        return {
          success: false,
          error: `INSUFFICIENT_POINTS: แต้มของคุณไม่เพียงพอ (คุณมี ${userPoints} แต้ม, ต้องการ ${item.pointsCost} แต้ม)`,
        };
      }

      const remainingPoints = userPoints - item.pointsCost;

      // Deduct points & update default shipping address on user table
      await db
        .update(users)
        .set({
          rewardPoints: remainingPoints,
          shippingAddress: body.shippingAddress,
          shippingPhone: body.phoneNumber,
          shippingRecipientName: body.recipientName,
          updatedAt: new Date(),
        })
        .where(eq(users.id, user.id));

      // Decrement stock
      await db
        .update(rewardItems)
        .set({
          inStock: item.inStock - 1,
          updatedAt: new Date(),
        })
        .where(eq(rewardItems.id, item.id));

      // Create redemption record
      const [redemption] = await db
        .insert(rewardRedemptions)
        .values({
          userId: user.id,
          rewardItemId: item.id,
          pointsSpent: item.pointsCost,
          status: "pending_delivery",
          recipientName: body.recipientName,
          phoneNumber: body.phoneNumber,
          shippingAddress: body.shippingAddress,
        })
        .returning();

      return {
        success: true,
        message: "แลกรับของรางวัลสำเร็จ! ทางเราจะจัดส่งสินค้าไปยังที่อยู่ของคุณ",
        data: {
          redemptionId: redemption.id,
          rewardItem: {
            id: item.id,
            title: item.title,
            imageUrl: item.imageUrl,
            pointsCost: item.pointsCost,
          },
          recipientName: body.recipientName,
          phoneNumber: body.phoneNumber,
          shippingAddress: body.shippingAddress,
          pointsSpent: item.pointsCost,
          remainingPoints,
          status: redemption.status,
          createdAt: redemption.createdAt.toISOString(),
        }
      };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    body: t.Object({
      rewardItemId: t.String({ format: "uuid" }),
      recipientName: t.String({ minLength: 1 }),
      phoneNumber: t.String({ minLength: 9, maxLength: 20 }),
      shippingAddress: t.String({ minLength: 5 }),
    }),
    detail: {
      tags: ["Rewards"],
      summary: "Redeem Reward Item with Shipping Address",
      description: "Redeem gift with reward points, deduct user points, save shipping address to DB, and record redemption order.",
    }
  })

  // 4. Get User Redemption History
  .get("/history", async ({ user, set }) => {
    try {
      const redemptions = await db.query.rewardRedemptions.findMany({
        where: eq(rewardRedemptions.userId, user.id),
        with: {
          rewardItem: true,
        },
        orderBy: [desc(rewardRedemptions.createdAt)],
      });

      return {
        success: true,
        data: {
          items: redemptions.map((r) => ({
            id: r.id,
            pointsSpent: r.pointsSpent,
            status: r.status,
            recipientName: r.recipientName,
            phoneNumber: r.phoneNumber,
            shippingAddress: r.shippingAddress,
            trackingNumber: r.trackingNumber,
            createdAt: r.createdAt.toISOString(),
            rewardItem: {
              id: r.rewardItem.id,
              title: r.rewardItem.title,
              description: r.rewardItem.description,
              imageUrl: r.rewardItem.imageUrl,
              category: r.rewardItem.category,
            },
          })),
        }
      };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    detail: {
      tags: ["Rewards"],
      summary: "Get user reward redemption history",
      description: "Retrieve past redeemed rewards and their delivery status.",
    }
  });
