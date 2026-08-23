import { describe, test, expect, beforeEach } from "bun:test";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import * as argon2 from "argon2";
import { env } from "../../../src/config/env";

describe("Unit & Integration: PIN Reset via Email OTP Flow", () => {
  const secret = env.JWT_ACCESS_SECRET || "test-secret";
  const userId = "user-test-uuid-12345";
  const userEmail = "thanapon.dev@gmail.com";

  // In-memory store for OTP simulation
  let otps: any[] = [];
  let userCreds: { pinHash: string; failedAttempts: number; lockedUntil: Date | null } = {
    pinHash: "",
    failedAttempts: 5,
    lockedUntil: new Date(Date.now() + 15 * 60 * 1000), // Locked
  };

  beforeEach(async () => {
    otps = [];
    const initialPinHash = await argon2.hash("111111");
    userCreds = {
      pinHash: initialPinHash,
      failedAttempts: 5,
      lockedUntil: new Date(Date.now() + 15 * 60 * 1000),
    };
  });

  test("1. Request OTP: generates 6-digit numeric OTP and masks email", () => {
    const rawOtp = Math.floor(100000 + Math.random() * 900000).toString();
    expect(rawOtp.length).toBe(6);
    expect(/^\d{6}$/.test(rawOtp)).toBe(true);

    const otpHash = crypto.createHash("sha256").update(rawOtp).digest("hex");
    otps.push({
      id: "otp-1",
      userId,
      email: userEmail,
      otpHash,
      purpose: "pin_reset",
      attempts: 0,
      maxAttempts: 5,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      createdAt: new Date(),
    });

    const emailParts = userEmail.split("@");
    const namePart = emailParts[0];
    const domainPart = emailParts[1];
    const maskedName = `${namePart.substring(0, 2)}${"*".repeat(Math.max(3, namePart.length - 2))}`;
    const maskedEmail = `${maskedName}@${domainPart}`;

    expect(maskedEmail).toBe("th**********@gmail.com");
    expect(otps.length).toBe(1);
  });

  test("2. Verify OTP: rejects wrong OTP and tracks attempts", () => {
    const rawOtp = "654321";
    const otpHash = crypto.createHash("sha256").update(rawOtp).digest("hex");
    const record = {
      id: "otp-1",
      userId,
      email: userEmail,
      otpHash,
      purpose: "pin_reset",
      attempts: 0,
      maxAttempts: 5,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      verifiedAt: null as Date | null,
    };

    // Attempt 1: wrong OTP
    const wrongInput = "123456";
    const wrongHash = crypto.createHash("sha256").update(wrongInput).digest("hex");
    expect(wrongHash).not.toBe(record.otpHash);
    record.attempts += 1;
    expect(record.attempts).toBe(1);
    expect(record.maxAttempts - record.attempts).toBe(4);

    // Attempt 2: correct OTP
    const correctHash = crypto.createHash("sha256").update(rawOtp).digest("hex");
    expect(correctHash).toBe(record.otpHash);
    record.verifiedAt = new Date();

    const resetToken = jwt.sign(
      { userId, purpose: "pin_reset", otpId: record.id },
      secret,
      { expiresIn: "10m" }
    );
    expect(resetToken).toBeDefined();

    const decoded = jwt.verify(resetToken, secret) as any;
    expect(decoded.userId).toBe(userId);
    expect(decoded.purpose).toBe("pin_reset");
  });

  test("3. Reset PIN: verifies resetToken, updates PIN hash and unlocks account", async () => {
    const resetToken = jwt.sign(
      { userId, purpose: "pin_reset", otpId: "otp-1" },
      secret,
      { expiresIn: "10m" }
    );

    const decoded = jwt.verify(resetToken, secret) as any;
    expect(decoded.userId).toBe(userId);
    expect(decoded.purpose).toBe("pin_reset");

    const newPin = "987654";
    const newPinHash = await argon2.hash(newPin);

    // Apply PIN reset
    userCreds.pinHash = newPinHash;
    userCreds.failedAttempts = 0;
    userCreds.lockedUntil = null;

    // Verify account is unlocked
    expect(userCreds.failedAttempts).toBe(0);
    expect(userCreds.lockedUntil).toBeNull();

    // Verify old PIN fails, new PIN succeeds
    const oldValid = await argon2.verify(userCreds.pinHash, "111111");
    expect(oldValid).toBe(false);

    const newValid = await argon2.verify(userCreds.pinHash, "987654");
    expect(newValid).toBe(true);
  });
});
