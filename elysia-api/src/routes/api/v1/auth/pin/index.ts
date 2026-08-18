import { Elysia, t } from "elysia";
import { db } from "../../../../../db";
import { userCredentials, securityEvents } from "../../../../../db/schema";
import { eq } from "drizzle-orm";
import jwt from "jsonwebtoken";
import { env } from "../../../../../config/env";
import * as argon2 from "argon2";

const requireAuth = (app: Elysia) => 
  app.derive(async ({ cookie: { access_token } }) => {
    if (!access_token.value) {
      return { userId: null, authError: "Unauthorized" };
    }
    try {
      const decoded = jwt.verify(access_token.value, env.JWT_ACCESS_SECRET) as { userId: string };
      return { userId: decoded.userId, authError: null };
    } catch {
      return { userId: null, authError: "Unauthorized" };
    }
  })
  .onBeforeHandle(({ authError, set }) => {
    if (authError) {
      set.status = 401;
      throw new Error(authError);
    }
  });

const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 15;

export default new Elysia()
  .use(requireAuth)
  .post("/setup", async ({ userId, body, set }) => {
    const { pin } = body;

    const existingCreds = await db.query.userCredentials.findFirst({
      where: eq(userCredentials.userId, userId)
    });

    if (existingCreds && existingCreds.pinHash) {
      set.status = 400;
      return { error: "PIN already set up" };
    }

    const pinHash = await argon2.hash(pin);

    await db.insert(userCredentials)
      .values({
        userId,
        pinHash,
      })
      .onConflictDoUpdate({
        target: userCredentials.userId,
        set: { pinHash }
      });

    return { success: true, message: "PIN created successfully." };
  }, {
    body: t.Object({
      pin: t.String({ minLength: 6, maxLength: 6 })
    }),
    detail: { tags: ["Auth PIN"], summary: "Setup 6-digit PIN" }
  })
  .post("/verify", async ({ userId, body, set }) => {
    const { pin } = body;

    const creds = await db.query.userCredentials.findFirst({
      where: eq(userCredentials.userId, userId)
    });

    if (!creds || !creds.pinHash) {
      set.status = 400;
      return { error: "PIN not set up" };
    }

    if (creds.lockedUntil && creds.lockedUntil > new Date()) {
      set.status = 429;
      return { error: "Account temporarily locked due to too many failed attempts" };
    }

    const isValid = await argon2.verify(creds.pinHash, pin);

    if (!isValid) {
      const newAttempts = creds.failedAttempts + 1;
      let lockedUntil = null;

      if (newAttempts >= MAX_FAILED_ATTEMPTS) {
        lockedUntil = new Date(Date.now() + LOCKOUT_MINUTES * 60 * 1000);
        
        // Log security event
        await db.insert(securityEvents).values({
          userId,
          event: "pin_brute_force",
          metadata: { attempts: newAttempts, lockoutMinutes: LOCKOUT_MINUTES }
        });
      }

      await db.update(userCredentials)
        .set({ 
          failedAttempts: newAttempts,
          lockedUntil,
          updatedAt: new Date()
        })
        .where(eq(userCredentials.userId, userId));

      set.status = 401;
      return { error: "Invalid PIN", attemptsLeft: Math.max(0, MAX_FAILED_ATTEMPTS - newAttempts) };
    }

    // Reset failed attempts on success
    if (creds.failedAttempts > 0) {
      await db.update(userCredentials)
        .set({
          failedAttempts: 0,
          lockedUntil: null,
          updatedAt: new Date()
        })
        .where(eq(userCredentials.userId, userId));
    }

    return { success: true };
  }, {
    body: t.Object({
      pin: t.String({ minLength: 6, maxLength: 6, pattern: "^[0-9]+$" })
    }),
    detail: { tags: ["Auth PIN"], summary: "Verify 6-digit PIN" }
  });
