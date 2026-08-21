import { Elysia } from "elysia";
import { env } from "./config/env";
import logixlysia from 'logixlysia';
import { openapi } from "@elysia/openapi";
import { autoload } from "elysia-autoload";
import { rateLimit } from "elysia-rate-limit";
import { cors } from "@elysiajs/cors";

export const app = new Elysia()
  .use(cors({
    origin: true,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "Accept", "Cookie"],
    exposeHeaders: ["Set-Cookie"],
  }))
  .use(logixlysia())
  .onError(({ code, error, set }) => {
    if (code === 'NOT_FOUND') return;
    
    const message = error instanceof Error ? error.message : String(error);
    
    if (message.toLowerCase().includes("unauthorized") || message.includes("Invalid access token") || message.includes("Missing access token") || message.includes("jwt expired")) {
      set.status = 401;
      return { error: message, message };
    }
    if (message.includes("Forbidden") || message.includes("Developer role required")) {
      set.status = 403;
      return { error: message, message };
    }
    if (message.includes("User not found")) {
      set.status = 404;
      return { error: message, message };
    }
  })
  .use(await autoload({ dir: `${import.meta.dir}/routes` }))
  .use(openapi({
    path: "/docs",
    documentation: {
      info: {
        title: "Friend Debt App API",
        version: "1.0.0"
      }
    }
  }));

// In standard server environments (Non-Vercel Serverless), listen to port & run background worker
if (process.env.VERCEL !== "1") {
  app.listen(env.PORT);
  
  // Start background notification worker
  import("./modules/notifications/notification-worker.service").then(({ defaultNotificationWorkerService }) => {
    defaultNotificationWorkerService.start(3000);
  });

  console.log(
    `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
  );
}

export default app;
export type App = typeof app;

