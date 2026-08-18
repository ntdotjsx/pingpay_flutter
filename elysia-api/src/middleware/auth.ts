import { Elysia } from "elysia";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { db } from "../db";
import { users, consentRecords, userCredentials } from "../db/schema";
import { eq } from "drizzle-orm";

export const authGuard = (app: Elysia) =>
  app.derive(async ({ cookie: { access_token } }) => {
    if (!access_token.value) {
      return { userId: null, authError: "Unauthorized: Missing access token" };
    }
    try {
      const decoded = jwt.verify(
        access_token.value,
        env.JWT_ACCESS_SECRET
      ) as { userId: string };
      return { userId: decoded.userId, authError: null };
    } catch {
      return { userId: null, authError: "Unauthorized: Invalid access token" };
    }
  })
  .onBeforeHandle(({ authError, set }) => {
    if (authError) {
      set.status = 401;
      throw new Error(authError);
    }
  });

export const onboardingGuard = (app: Elysia) =>
  app.use(authGuard)
  .derive(async ({ userId }) => {
    if (!userId) return { user: null as any, onboardingState: null, onboardError: "Unauthorized" };
    const user = await db.query.users.findFirst({
      where: eq(users.id, userId),
    });

    if (!user) {
      return { user: null as any, onboardingState: null, onboardError: "User not found" };
    }

    const consent = await db.query.consentRecords.findFirst({
      where: eq(consentRecords.userId, userId),
      orderBy: (records, { desc }) => [desc(records.acceptedAt)],
    });

    const creds = await db.query.userCredentials.findFirst({
      where: eq(userCredentials.userId, userId),
    });

    let onboardingState = "COMPLETED";

    if (!consent) {
      onboardingState = "PDPA_REQUIRED";
    } else if (!user.profileCompletedAt) {
      onboardingState = "PROFILE_REQUIRED";
    } else if (!creds || !creds.pinHash) {
      onboardingState = "PIN_REQUIRED";
    }

    return { user, onboardingState, onboardError: null };
  })
  .onBeforeHandle(({ onboardError, set }) => {
    if (onboardError) {
      set.status = onboardError === "User not found" ? 404 : 401;
      throw new Error(onboardError);
    }
  });
