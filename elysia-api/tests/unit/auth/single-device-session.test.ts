import { describe, it, expect, beforeEach } from "bun:test";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import { db } from "../../../src/db";
import { users, authSessions, authIdentities } from "../../../src/db/schema";
import { eq } from "drizzle-orm";
import { env } from "../../../src/config/env";
import { app } from "../../../src";

describe("Single Device Session Policy (One Active Device)", () => {
  let testUserId: string;

  beforeEach(async () => {
    // Find or create a test user
    let existing = await db.query.users.findFirst({
      where: eq(users.email, "single_device_test@pingpay.app"),
    });

    if (existing) {
      testUserId = existing.id;
      await db.delete(authSessions).where(eq(authSessions.userId, testUserId));
    } else {
      const [newUser] = await db.insert(users).values({
        email: "single_device_test@pingpay.app",
        displayName: "Single Device Tester",
        userCode: "USR-DEVTEST",
      }).returning();
      testUserId = newUser.id;

      await db.insert(authIdentities).values({
        userId: testUserId,
        provider: "google",
        providerUserId: "mock_device_single_user",
      });
    }
  });

  it("1. Should allow Device A to login and access protected routes", async () => {
    // Simulate Device A Login
    const resA = await app.handle(
      new Request("http://localhost/api/v1/auth/google/verify-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          mockGoogleId: "mock_device_single_user",
          mockEmail: "single_device_test@pingpay.app",
          mockDisplayName: "Single Device Tester",
          deviceName: "iPhone 15 Pro",
          platform: "ios",
        }),
      })
    );

    expect(resA.status).toBe(200);
    const dataA = await resA.json();
    expect(dataA.accessToken).toBeDefined();

    // Verify Device A can call /me
    const meResA = await app.handle(
      new Request("http://localhost/api/v1/auth/me", {
        headers: { Authorization: `Bearer ${dataA.accessToken}` },
      })
    );
    expect(meResA.status).toBe(200);
  });

  it("2. When Device B logs in, Device A must be kicked out (SESSION_TERMINATED)", async () => {
    // Device A Login
    const resA = await app.handle(
      new Request("http://localhost/api/v1/auth/google/verify-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          mockGoogleId: "mock_device_single_user",
          mockEmail: "single_device_test@pingpay.app",
          deviceName: "Device A (iPhone)",
          platform: "ios",
        }),
      })
    );
    const dataA = await resA.json();
    const tokenA = dataA.accessToken;
    const refreshTokenA = dataA.refreshToken;

    // Verify Device A works
    const meResA1 = await app.handle(
      new Request("http://localhost/api/v1/auth/me", {
        headers: { Authorization: `Bearer ${tokenA}` },
      })
    );
    expect(meResA1.status).toBe(200);

    // Device B Login with same account
    const resB = await app.handle(
      new Request("http://localhost/api/v1/auth/google/verify-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          mockGoogleId: "mock_device_single_user",
          mockEmail: "single_device_test@pingpay.app",
          deviceName: "Device B (Android Pixel 8)",
          platform: "android",
        }),
      })
    );
    expect(resB.status).toBe(200);
    const dataB = await resB.json();
    const tokenB = dataB.accessToken;

    // Device B can access /me
    const meResB = await app.handle(
      new Request("http://localhost/api/v1/auth/me", {
        headers: { Authorization: `Bearer ${tokenB}` },
      })
    );
    expect(meResB.status).toBe(200);

    // Device A tries to access /me -> Must be rejected with 401 SESSION_TERMINATED
    const meResA2 = await app.handle(
      new Request("http://localhost/api/v1/auth/me", {
        headers: { Authorization: `Bearer ${tokenA}` },
      })
    );
    expect(meResA2.status).toBe(401);

    // Device A tries to refresh token -> Must be rejected with 401
    const refreshResA = await app.handle(
      new Request("http://localhost/api/v1/auth/refresh", {
        method: "POST",
        headers: { Cookie: `refresh_token=${refreshTokenA}` },
      })
    );
    expect(refreshResA.status).toBe(401);
  });
});
