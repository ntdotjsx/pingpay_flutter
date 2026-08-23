import { Elysia } from "elysia";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { db } from "../db";
import { users, consentRecords, userCredentials, authSessions } from "../db/schema";
import { eq, and } from "drizzle-orm";

export const authGuard = (app: Elysia) =>
  app.derive(async ({ cookie: { access_token }, headers }) => {
    let token = access_token.value;

    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader && authHeader.startsWith("Bearer ")) {
      token = authHeader.substring(7);
    }

    if (!token) {
      return { userId: null, sessionId: null, authError: "Unauthorized: Missing access token" };
    }
    try {
      const decoded = jwt.verify(
        token,
        env.JWT_ACCESS_SECRET
      ) as { userId: string; sessionId?: string };

      if (decoded.sessionId) {
        // Enforce Single Active Device Session Policy
        const session = await db.query.authSessions.findFirst({
          where: and(eq(authSessions.id, decoded.sessionId), eq(authSessions.userId, decoded.userId)),
        });

        if (!session) {
          return {
            userId: null,
            sessionId: null,
            authError: "SESSION_TERMINATED: บัญชีนี้มีการเข้าสู่ระบบจากอุปกรณ์อื่น ระบบได้นำคุณออกจากระบบนี้เพื่อความปลอดภัย",
          };
        }
      }

      return { userId: decoded.userId, sessionId: decoded.sessionId ?? null, authError: null };
    } catch {
      return { userId: null, sessionId: null, authError: "Unauthorized: Invalid access token" };
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
    } else if (!creds || !creds.pinHash) {
      onboardingState = "PIN_REQUIRED";
    } else if (!user.profileCompletedAt) {
      onboardingState = "PROFILE_REQUIRED";
    }

    return { user, onboardingState, onboardError: null };
  })
  .onBeforeHandle(({ onboardError, set }) => {
    if (onboardError) {
      set.status = onboardError === "User not found" ? 404 : 401;
      throw new Error(onboardError);
    }
  });
