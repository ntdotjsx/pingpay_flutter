import { Elysia } from "elysia";
import { authenticateAccessToken } from "../middleware/auth";
import { realtimeService } from "./realtime.service";

function extractBearerToken(headers: Record<string, string | undefined>, query: Record<string, unknown>, cookieToken?: string) {
  const authHeader = headers.authorization || headers.Authorization;
  if (authHeader?.startsWith("Bearer ")) {
    return authHeader.substring(7);
  }

  const queryToken = query.token;
  if (typeof queryToken === "string" && queryToken.length > 0) {
    return queryToken;
  }

  return cookieToken;
}

export const realtimeRoutes = new Elysia()
  .derive(async ({ headers, query, cookie: { access_token } }) => {
    const token = extractBearerToken(headers as Record<string, string | undefined>, query as Record<string, unknown>, access_token.value);
    const auth = await authenticateAccessToken(token);
    return {
      realtimeUserId: auth.userId,
      realtimeAuthError: auth.authError,
    };
  })
  .ws("/", {
    open(ws) {
      const userId = ws.data.realtimeUserId;
      if (!userId) {
        console.warn(`[Realtime] Unauthorized WebSocket connection: ${ws.data.realtimeAuthError}`);
        ws.close(4001, "Unauthorized");
        return;
      }

      realtimeService.connect(userId, ws);
    },
    message(ws, message) {
      const userId = ws.data.realtimeUserId;
      if (!userId) return;

      if (message === "ping") {
        ws.send("pong");
      }
    },
    close(ws) {
      const userId = ws.data.realtimeUserId;
      if (userId) {
        realtimeService.disconnect(userId, ws);
      }
    },
  });
