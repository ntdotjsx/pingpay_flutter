import { Elysia } from "elysia";
import { onboardingGuard, authGuard } from "../../../../../middleware/auth";
import { db } from "../../../../../db";
import { authSessions } from "../../../../../db/schema";
import { eq } from "drizzle-orm";

export default new Elysia()
  .use(onboardingGuard)
  .get("/", ({ user, onboardingState }) => {
    return {
      userId: user.id,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      onboardingState,
    };
  }, { detail: { tags: ["Auth"], summary: "Get current user session info" } })
  .post("/logout", async ({ cookie: { access_token, refresh_token }, set }) => {
    // In a real app we'd find the session and revoke it here.
    
    // Clear cookies
    access_token.remove();
    refresh_token.remove();
    
    return { success: true };
  }, { detail: { tags: ["Auth"], summary: "Logout current user" } });
