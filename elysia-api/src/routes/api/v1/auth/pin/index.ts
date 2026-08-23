import { Elysia, t } from "elysia";
import { db } from "../../../../../db";
import { userCredentials, securityEvents, users, authIdentities, otpVerifications, authSessions } from "../../../../../db/schema";
import { eq, and } from "drizzle-orm";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import { env } from "../../../../../config/env";
import * as argon2 from "argon2";

const requireAuth = (app: Elysia) => 
  app.derive(async ({ cookie: { access_token }, headers }) => {
    let token = access_token.value;
    const authHeader = headers.authorization || headers.Authorization;
    if (authHeader && authHeader.startsWith("Bearer ")) {
      token = authHeader.substring(7);
    }

    if (!token) {
      return { userId: null, authError: "Unauthorized" };
    }
    try {
      const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as { userId: string; sessionId?: string };
      if (decoded.sessionId) {
        const session = await db.query.authSessions.findFirst({
          where: and(eq(authSessions.id, decoded.sessionId), eq(authSessions.userId, decoded.userId)),
        });
        if (!session) {
          return {
            userId: null,
            authError: "SESSION_TERMINATED: บัญชีนี้มีการเข้าสู่ระบบจากอุปกรณ์อื่น ระบบได้นำคุณออกจากระบบนี้เพื่อความปลอดภัย",
          };
        }
      }
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

const MAX_FAILED_ATTEMPTS = 3;

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

    const cleanPin = pin.trim();
    const pinHash = await argon2.hash(cleanPin);

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
      pin: t.String({ minLength: 6, maxLength: 6, pattern: "^[0-9]+$" })
    }),
    detail: { tags: ["Auth PIN"], summary: "Setup 6-digit PIN" }
  })
  .post("/change", async ({ userId, body, set }) => {
    const { currentPin, newPin } = body;

    const creds = await db.query.userCredentials.findFirst({
      where: eq(userCredentials.userId, userId)
    });

    if (creds && creds.pinHash) {
      if (!currentPin) {
        set.status = 400;
        return { error: "CURRENT_PIN_REQUIRED", message: "กรุณาระบุรหัส PIN ปัจจุบัน" };
      }

      const isValid = await argon2.verify(creds.pinHash, currentPin.trim());
      if (!isValid) {
        set.status = 400;
        return { error: "INVALID_CURRENT_PIN", message: "รหัส PIN ปัจจุบันไม่ถูกต้อง" };
      }
    }

    const cleanNewPin = newPin.trim();
    const pinHash = await argon2.hash(cleanNewPin);

    await db.insert(userCredentials)
      .values({
        userId,
        pinHash,
        failedAttempts: 0,
        lockedUntil: null,
      })
      .onConflictDoUpdate({
        target: userCredentials.userId,
        set: {
          pinHash,
          failedAttempts: 0,
          lockedUntil: null,
          updatedAt: new Date(),
        }
      });

    await db.insert(securityEvents).values({
      userId,
      event: "pin_changed",
      metadata: { changedAt: new Date() }
    }).catch(() => {});

    return { success: true, message: "เปลี่ยนรหัส PIN สำเร็จเรียบร้อยแล้ว" };
  }, {
    body: t.Object({
      currentPin: t.Optional(t.String({ minLength: 6, maxLength: 6, pattern: "^[0-9]+$" })),
      newPin: t.String({ minLength: 6, maxLength: 6, pattern: "^[0-9]+$" })
    }),
    detail: { tags: ["Auth PIN"], summary: "Change 6-digit PIN" }
  })
  .post("/verify", async ({ userId, body, set }) => {
    const { pin } = body;

    const creds = await db.query.userCredentials.findFirst({
      where: eq(userCredentials.userId, userId)
    });

    if (!creds || !creds.pinHash) {
      set.status = 400;
      return { error: "PIN_NOT_SET", message: "ยังไม่ได้ตั้งค่ารหัส PIN" };
    }

    // If already locked out due to 3 failed attempts
    if (creds.failedAttempts >= MAX_FAILED_ATTEMPTS || (creds.lockedUntil && creds.lockedUntil > new Date())) {
      set.status = 429;
      return {
        error: "ACCOUNT_LOCKED",
        isLockedOut: true,
        message: `คุณกรอกรหัส PIN ผิดเกิน ${MAX_FAILED_ATTEMPTS} ครั้ง บัญชีถูกล็อกเพื่อความปลอดภัย กรุณากด "ลืมรหัส PIN?" เพื่อยืนยันตัวตนผ่าน Email OTP และตั้งรหัส PIN ใหม่`,
        lockedUntil: creds.lockedUntil
      };
    }

    const cleanPin = body.pin.trim();
    const isValid = await argon2.verify(creds.pinHash, cleanPin);

    if (!isValid) {
      const newAttempts = creds.failedAttempts + 1;
      let lockedUntil: Date | null = null;

      if (newAttempts >= MAX_FAILED_ATTEMPTS) {
        // Lock until Email OTP reset is performed
        lockedUntil = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
        
        // Log security event
        await db.insert(securityEvents).values({
          userId,
          event: "pin_brute_force_locked",
          metadata: { attempts: newAttempts, requiredAction: "email_otp_reset" }
        });
      }

      await db.update(userCredentials)
        .set({ 
          failedAttempts: newAttempts,
          lockedUntil,
          updatedAt: new Date()
        })
        .where(eq(userCredentials.userId, userId));

      const attemptsLeft = Math.max(0, MAX_FAILED_ATTEMPTS - newAttempts);

      if (attemptsLeft === 0) {
        set.status = 429;
        return {
          error: "ACCOUNT_LOCKED",
          isLockedOut: true,
          message: `คุณกรอกรหัส PIN ผิดครบ ${MAX_FAILED_ATTEMPTS} ครั้งแล้ว บัญชีถูกระงับเพื่อความปลอดภัย กรุณายืนยันรหัส OTP ผ่าน Email เพื่อรีเซ็ตรหัส PIN ใหม่`,
          attemptsLeft: 0
        };
      }

      set.status = 400;
      return {
        error: "INVALID_PIN",
        isLockedOut: false,
        message: `รหัส PIN ไม่ถูกต้อง (เหลือโอกาสอีก ${attemptsLeft} ครั้ง)`,
        attemptsLeft
      };
    }

    // Reset failed attempts & unlock on success
    if (creds.failedAttempts > 0 || creds.lockedUntil !== null) {
      await db.update(userCredentials)
        .set({
          failedAttempts: 0,
          lockedUntil: null,
          updatedAt: new Date()
        })
        .where(eq(userCredentials.userId, userId));
    }

    return { success: true, message: "ยืนยันรหัส PIN ถูกต้อง" };
  }, {
    body: t.Object({
      pin: t.String({ minLength: 6, maxLength: 6, pattern: "^[0-9]+$" })
    }),
    detail: { tags: ["Auth PIN"], summary: "Verify 6-digit PIN" }
  })
  // ── Forgot PIN Flow via Email OTP ──────────────────────────────────────
  .post("/forgot/request-otp", async ({ userId, body, set }) => {
    try {
      const user = await db.query.users.findFirst({
        where: eq(users.id, userId)
      });

      if (!user) {
        set.status = 404;
        return { error: "USER_NOT_FOUND", message: "ไม่พบข้อมูลผู้ใช้งาน" };
      }

      const clientProvidedEmail = (body as any)?.email?.trim();

      // Check user email from profile or Google identity or client payload
      let targetEmail = user.email || clientProvidedEmail;
      if (!targetEmail) {
        // Check Google identity providerUserId or metadata
        const googleIdentity = await db.query.authIdentities.findFirst({
          where: and(eq(authIdentities.userId, userId), eq(authIdentities.provider, "google"))
        });
        if (googleIdentity?.providerUserId && googleIdentity.providerUserId.includes("@")) {
          targetEmail = googleIdentity.providerUserId;
        }
      }

      if (!targetEmail) {
        set.status = 400;
        return {
          error: "NO_EMAIL_CONFIGURED",
          message: "บัญชีของคุณยังไม่มี Email สำหรับรับรหัส OTP กรุณาระบุ Email หรือเข้าสู่ระบบใหม่ด้วย Google"
        };
      }

      // If user didn't have email saved in DB before, save it now
      if (!user.email && targetEmail) {
        await db.update(users).set({ email: targetEmail, updatedAt: new Date() }).where(eq(users.id, userId));
      }

      // Check rate limit (cooldown 60s)
      const recentOtp = await db.query.otpVerifications.findFirst({
        where: and(
          eq(otpVerifications.userId, userId),
          eq(otpVerifications.purpose, "pin_reset")
        ),
        orderBy: (table, { desc }) => [desc(table.createdAt)]
      });

      const now = new Date();
      if (recentOtp && (now.getTime() - new Date(recentOtp.createdAt).getTime()) < 60 * 1000) {
        const remainingSeconds = Math.ceil((60 * 1000 - (now.getTime() - new Date(recentOtp.createdAt).getTime())) / 1000);
        set.status = 429;
        return {
          error: "RATE_LIMITED",
          message: `กรุณารอ ${remainingSeconds} วินาที ก่อนขอรหัส OTP ใหม่อีกครั้ง`,
          cooldownSeconds: remainingSeconds
        };
      }

      // Generate 6-digit numeric OTP
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      const otpHash = crypto.createHash("sha256").update(otpCode).digest("hex");
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

      await db.insert(otpVerifications).values({
        userId,
        email: targetEmail,
        otpHash,
        purpose: "pin_reset",
        attempts: 0,
        maxAttempts: 5,
        expiresAt,
      });

      // Send OTP via Email Service
      const { defaultEmailService } = await import("../../../../../modules/email/email.service");
      await defaultEmailService.sendOtpEmail({
        toEmail: targetEmail,
        otp: otpCode,
        userName: user.displayName || user.fullName || "ผู้ใช้งาน",
        expiresInMinutes: 5,
      });

      // Mask email for privacy (e.g. thanapon@gmail.com -> th****@gmail.com)
      const emailParts = targetEmail.split("@");
      const namePart = emailParts[0];
      const domainPart = emailParts[1] || "";
      const maskedName = namePart.length > 2 
        ? `${namePart.substring(0, 2)}${"*".repeat(Math.max(3, namePart.length - 2))}`
        : `${namePart}***`;
      const maskedEmail = `${maskedName}@${domainPart}`;

      return {
        success: true,
        message: "ส่งรหัส OTP ไปยังอีเมลของคุณเรียบร้อยแล้ว",
        maskedEmail,
        expiresInSeconds: 300,
        cooldownSeconds: 60,
      };
    } catch (err: any) {
      set.status = 500;
      return { error: "INTERNAL_ERROR", message: err.message };
    }
  }, {
    body: t.Optional(t.Object({
      email: t.Optional(t.String()),
    })),
    detail: { tags: ["Auth PIN"], summary: "Request Email OTP for PIN Reset" }
  })
  .post("/forgot/verify-otp", async ({ userId, body, set }) => {
    const { otp } = body;
    const cleanOtp = otp.trim();

    const activeOtp = await db.query.otpVerifications.findFirst({
      where: and(
        eq(otpVerifications.userId, userId),
        eq(otpVerifications.purpose, "pin_reset")
      ),
      orderBy: (table, { desc }) => [desc(table.createdAt)]
    });

    if (!activeOtp || (activeOtp.expiresAt && new Date(activeOtp.expiresAt) < new Date())) {
      set.status = 400;
      return {
        error: "OTP_EXPIRED_OR_INVALID",
        message: "รหัส OTP หมดอายุหรือไม่ถูกต้อง กรุณากดขอรหัสใหม่"
      };
    }

    if (activeOtp.verifiedAt) {
      set.status = 400;
      return {
        error: "OTP_ALREADY_USED",
        message: "รหัส OTP นี้ถูกใช้งานไปแล้ว กรุณากดขอรหัสใหม่"
      };
    }

    if (activeOtp.attempts >= activeOtp.maxAttempts) {
      set.status = 429;
      return {
        error: "OTP_MAX_ATTEMPTS_EXCEEDED",
        message: "กรอกรหัส OTP ผิดเกินจำนวนครั้งที่กำหนด กรุณากดขอรหัสใหม่"
      };
    }

    const inputHash = crypto.createHash("sha256").update(cleanOtp).digest("hex");
    if (inputHash !== activeOtp.otpHash) {
      const newAttempts = activeOtp.attempts + 1;
      await db.update(otpVerifications)
        .set({ attempts: newAttempts, updatedAt: new Date() })
        .where(eq(otpVerifications.id, activeOtp.id));

      set.status = 400;
      return {
        error: "INVALID_OTP",
        message: "รหัส OTP ไม่ถูกต้อง",
        attemptsLeft: Math.max(0, activeOtp.maxAttempts - newAttempts)
      };
    }

    // Mark verified
    await db.update(otpVerifications)
      .set({ verifiedAt: new Date(), updatedAt: new Date() })
      .where(eq(otpVerifications.id, activeOtp.id));

    // Generate signed resetToken (valid for 10 minutes)
    const resetToken = jwt.sign(
      { userId, purpose: "pin_reset", otpId: activeOtp.id },
      env.JWT_ACCESS_SECRET,
      { expiresIn: "10m" }
    );

    return {
      success: true,
      message: "ยืนยันรหัส OTP สำเร็จ",
      resetToken,
    };
  }, {
    body: t.Object({
      otp: t.String({ minLength: 6, maxLength: 6, pattern: "^[0-9]+$" })
    }),
    detail: { tags: ["Auth PIN"], summary: "Verify Email OTP for PIN Reset" }
  })
  .post("/forgot/reset", async ({ body, set }) => {
    const { resetToken, newPin } = body;

    try {
      const decoded = jwt.verify(resetToken, env.JWT_ACCESS_SECRET) as {
        userId: string;
        purpose: string;
        otpId: string;
      };

      if (!decoded || decoded.purpose !== "pin_reset" || !decoded.userId) {
        set.status = 401;
        return { error: "INVALID_RESET_TOKEN", message: "ลิงก์หรือโทเค็นสำหรับรีเซ็ต PIN ไม่ถูกต้องหรือหมดอายุ" };
      }

      const cleanPin = newPin.trim();
      const pinHash = await argon2.hash(cleanPin);

      // Update PIN hash & unlock account unconditionally
      const existing = await db.query.userCredentials.findFirst({
        where: eq(userCredentials.userId, decoded.userId)
      });

      if (existing) {
        await db.update(userCredentials)
          .set({
            pinHash,
            failedAttempts: 0,
            lockedUntil: null,
            updatedAt: new Date()
          })
          .where(eq(userCredentials.userId, decoded.userId));
      } else {
        await db.insert(userCredentials).values({
          userId: decoded.userId,
          pinHash,
          failedAttempts: 0,
          lockedUntil: null,
          updatedAt: new Date()
        });
      }

      // Log security event
      await db.insert(securityEvents).values({
        userId: decoded.userId,
        event: "pin_reset_via_otp",
        metadata: { otpId: decoded.otpId, resetAt: new Date() }
      });

      return {
        success: true,
        message: "ตั้งรหัส PIN ใหม่สำเร็จเรียบร้อยแล้ว",
      };
    } catch (e: any) {
      set.status = 401;
      return { error: "INVALID_RESET_TOKEN", message: "โทเค็นสำหรับรีเซ็ต PIN หมดอายุ กรุณาขอรหัส OTP ใหม่อีกครั้ง" };
    }
  }, {
    body: t.Object({
      resetToken: t.String(),
      newPin: t.String({ minLength: 6, maxLength: 6, pattern: "^[0-9]+$" })
    }),
    detail: { tags: ["Auth PIN"], summary: "Reset 6-digit PIN with verified token" }
  });
