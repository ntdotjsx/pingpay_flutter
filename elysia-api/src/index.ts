import { Elysia } from "elysia";
import { env } from "./config/env";
import logixlysia from 'logixlysia';
import { openapi } from "@elysia/openapi";
import { autoload } from "elysia-autoload";
import { rateLimit } from "elysia-rate-limit";

export const app = new Elysia()
  .use(logixlysia())
  .onError(({ code, error, set }) => {
    if (code === 'NOT_FOUND') return;
    
    const message = error instanceof Error ? error.message : String(error);
    
    if (message.includes("Unauthorized")) {
      set.status = 401;
      return { error: message };
    }
    if (message.includes("User not found")) {
      set.status = 404;
      return { error: message };
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
  }))
  .get("/", () => "Hello Elysia", { detail: { tags: ["General"], summary: "Health Check" } })
  .listen(env.PORT);

export type App = typeof app;

console.log(
  `🦊 Elysia is running at ${app.server?.hostname}:${app.server?.port}`
);
