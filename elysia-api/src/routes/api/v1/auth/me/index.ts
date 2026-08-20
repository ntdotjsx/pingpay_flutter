import { Elysia } from "elysia";
import { onboardingGuard, authGuard } from "../../../../../middleware/auth";
import { db } from "../../../../../db";
import { authSessions } from "../../../../../db/schema";
import { eq } from "drizzle-orm";

export default new Elysia()
  .use(onboardingGuard)
  .get("/", async ({ user, onboardingState }) => {
    let isLineFriend = false;

    // Check real-time friendship with LINE Official Account (@553ltsju)
    try {
      const identity = await db.query.authIdentities.findFirst({
        where: (ai, { and, eq }) => and(eq(ai.userId, user.id), eq(ai.provider, "line"))
      });

      if (identity?.providerUserId) {
        const token = process.env.LINE_CHANNEL_ACCESS_TOKEN;
        if (token) {
          const profileRes = await fetch(`https://api.line.me/v2/bot/profile/${identity.providerUserId}`, {
            headers: { Authorization: `Bearer ${token}` }
          });
          isLineFriend = profileRes.status === 200;
        }
      }
    } catch (_) {
      isLineFriend = false;
    }

    return {
      userId: user.id,
      userCode: user.userCode,
      displayName: user.displayName,
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      promptPayId: user.promptPayId,
      promptPayIdType: user.promptPayIdType,
      phoneNumber: user.phoneNumber,
      bankAccountNumber: user.bankAccountNumber,
      rewardPoints: user.rewardPoints ?? 27,
      shippingAddress: user.shippingAddress,
      shippingPhone: user.shippingPhone,
      shippingRecipientName: user.shippingRecipientName,
      onboardingState,
      isLineFriend,
    };
  }, { detail: { tags: ["Auth"], summary: "Get current user session info" } })
  .post("/logout", async ({ cookie: { access_token, refresh_token }, set }) => {
    // In a real app we'd find the session and revoke it here.
    
    // Clear cookies
    access_token.remove();
    refresh_token.remove();
    
    return { success: true };
  }, { detail: { tags: ["Auth"], summary: "Logout current user" } });
