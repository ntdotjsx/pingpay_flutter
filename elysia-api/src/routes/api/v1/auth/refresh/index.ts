import { Elysia, t } from "elysia";
import { db } from "../../../../../db";
import { authSessions } from "../../../../../db/schema";
import { eq, and } from "drizzle-orm";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import { env } from "../../../../../config/env";

export default new Elysia()
  .post("/", async ({ cookie: { refresh_token, access_token }, headers, set }) => {
    let token = refresh_token.value;
    const cookieHeader = headers.cookie || headers.Cookie;
    if (!token && cookieHeader) {
      const match = cookieHeader.match(/refresh_token=([^;]+)/);
      if (match) token = match[1];
    }

    if (!token) {
      set.status = 401;
      return { error: "No refresh token provided" };
    }

    try {
      // Verify refresh token
      const decoded = jwt.verify(token, env.JWT_REFRESH_SECRET) as { userId: string; sessionId?: string };
      const userId = decoded.userId;

      // Verify active session for single device policy
      let session = null;
      if (decoded.sessionId) {
        session = await db.query.authSessions.findFirst({
          where: and(eq(authSessions.id, decoded.sessionId), eq(authSessions.userId, userId)),
        });
      } else {
        session = await db.query.authSessions.findFirst({
          where: eq(authSessions.userId, userId),
        });
      }

      if (!session) {
        set.status = 401;
        return {
          error: "SESSION_TERMINATED",
          message: "บัญชีนี้มีการเข้าสู่ระบบจากอุปกรณ์อื่น ระบบได้นำคุณออกจากระบบนี้เพื่อความปลอดภัย",
        };
      }

      const activeSessionId = session.id;

      // Generate new tokens
      const newAccessToken = jwt.sign({ userId, sessionId: activeSessionId }, env.JWT_ACCESS_SECRET, { expiresIn: '15m' });
      const newRefreshToken = jwt.sign({ userId, sessionId: activeSessionId }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      const refreshTokenHash = crypto.createHash("sha256").update(newRefreshToken).digest("hex");
      await db.update(authSessions)
        .set({ refreshTokenHash, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) })
        .where(eq(authSessions.id, activeSessionId));

      access_token.set({
        value: newAccessToken,
        httpOnly: true,
        path: "/",
        maxAge: 15 * 60,
      });
      refresh_token.set({
        value: newRefreshToken,
        httpOnly: true,
        path: "/",
        maxAge: 7 * 24 * 60 * 60,
      });

      return {
        success: true,
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        message: "Tokens refreshed"
      };
    } catch (e) {
      set.status = 401;
      return { error: "Invalid refresh token" };
    }
  }, { 
    detail: { 
      tags: ["Auth"],
      summary: "Refresh Access Token",
      description: "Exchange a valid refresh token for a new access token and refresh token."
    } 
  });
