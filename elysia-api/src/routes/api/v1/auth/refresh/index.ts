import { Elysia, t } from "elysia";
import { db } from "../../../../../db";
import { authSessions } from "../../../../../db/schema";
import { eq } from "drizzle-orm";
import jwt from "jsonwebtoken";
import { env } from "../../../../../config/env";
import * as argon2 from "argon2";

export default new Elysia()
  .post("/", async ({ cookie: { refresh_token, access_token }, set }) => {
    if (!refresh_token.value) {
      set.status = 401;
      return { error: "No refresh token provided" };
    }

    try {
      // Verify refresh token
      const decoded = jwt.verify(refresh_token.value, env.JWT_REFRESH_SECRET) as { userId: string };
      const userId = decoded.userId;

      // Generate new tokens
      const newAccessToken = jwt.sign({ userId }, env.JWT_ACCESS_SECRET, { expiresIn: '15m' });
      const newRefreshToken = jwt.sign({ userId }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      // In a full implementation we would:
      // 1. Verify the old refresh token against authSessions in DB (using argon2 verify)
      // 2. Detect refresh token reuse (if old token used, revoke all sessions)
      // 3. Delete old session, insert new session with hashed newRefreshToken

      // For this phase, we issue new tokens and update cookies
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
