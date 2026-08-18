import { Elysia, t } from "elysia";
import { db } from "../../../../../db";
import { authOauthStates, authIdentities, users } from "../../../../../db/schema";
import { env } from "../../../../../config/env";
import { eq } from "drizzle-orm";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import { randomBytes } from "crypto";

// Mock LINE API for testing
const mockLineLogin = async (code: string) => {
  return {
    sub: `mock_line_user_${code}`,
    name: "Mock Line User",
    picture: "https://example.com/avatar.jpg"
  };
};

export default new Elysia({ prefix: "/line" })
  .get("/", async ({ redirect }) => {
    // Generate state and code verifier
    const state = randomBytes(32).toString("hex");
    const codeVerifier = randomBytes(32).toString("hex");
    
    // Store state in DB
    await db.insert(authOauthStates).values({
      state,
      codeVerifier,
      redirectUri: env.LINE_CALLBACK_URL,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000), // 10 mins expiry
    });

    const authUrl = new URL("https://access.line.me/oauth2/v2.1/authorize");
    authUrl.searchParams.append("response_type", "code");
    authUrl.searchParams.append("client_id", env.LINE_CHANNEL_ID);
    authUrl.searchParams.append("redirect_uri", env.LINE_CALLBACK_URL);
    authUrl.searchParams.append("state", state);
    authUrl.searchParams.append("scope", "profile openid");

    return redirect(authUrl.toString());
  }, { 
    detail: { 
      tags: ['Auth LINE'], 
      summary: "LINE Login Redirect", 
      description: "Redirect the client to LINE's OAuth 2.0 login page." 
    } 
  })
  .get("/callback", async ({ query, set, cookie: { access_token, refresh_token } }) => {
    const { code, state, error } = query;

    if (error || !code || !state) {
      set.status = 400;
      return { error: "Invalid callback request" };
    }

    // Verify state
    const stateRecord = await db.query.authOauthStates.findFirst({
      where: eq(authOauthStates.state, state)
    });

    if (!stateRecord || stateRecord.expiresAt < new Date()) {
      set.status = 400;
      return { error: "Invalid or expired state" };
    }

    // Delete state
    await db.delete(authOauthStates).where(eq(authOauthStates.state, state));

    // Mock LINE login
    const lineProfile = await mockLineLogin(code);

    // Find or create identity
    let identity = await db.query.authIdentities.findFirst({
      where: eq(authIdentities.providerUserId, lineProfile.sub)
    });

    let userId: string;

    if (!identity) {
      const userCode = `USR-${crypto.randomBytes(3).toString("hex").toUpperCase()}`;
      const [newUser] = await db.insert(users).values({
        userCode,
        displayName: lineProfile.name,
        avatarUrl: lineProfile.picture,
      }).returning();

      userId = newUser.id;

      // Create identity
      await db.insert(authIdentities).values({
        userId,
        provider: "line",
        providerUserId: lineProfile.sub,
      });
    } else {
      userId = identity.userId;
    }

    // Issue JWTs
    const accessToken = jwt.sign({ userId }, env.JWT_ACCESS_SECRET, { expiresIn: '15m' });
    const refreshToken = jwt.sign({ userId }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

    // In a real app we'd hash the refresh token and save it to authSessions
    // Skipping session DB insertion for this simple callback for now
    
    // Set cookies
    access_token.set({
      value: accessToken,
      httpOnly: true,
      path: "/",
      maxAge: 15 * 60,
    });
    refresh_token.set({
      value: refreshToken,
      httpOnly: true,
      path: "/",
      maxAge: 7 * 24 * 60 * 60,
    });

    return { message: "Login successful", accessToken, refreshToken };
  }, {
    detail: { 
      tags: ['Auth LINE'], 
      summary: "LINE Login Callback", 
      description: "Handle the callback from LINE OAuth 2.0, verify the token, and authenticate or create the user." 
    },
    query: t.Object({
      code: t.Optional(t.String()),
      state: t.Optional(t.String()),
      error: t.Optional(t.String()),
    })
  });
