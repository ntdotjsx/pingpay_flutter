import { describe, it, expect } from "bun:test";
import { env } from "../src/config/env";

describe("Environment Validation", () => {
  it("should have loaded all environment variables", () => {
    expect(env.DATABASE_URL).toBeDefined();
    expect(env.LINE_MOBILE_CHANNEL_ID).toBeDefined();
    expect(env.LINE_CHANNEL_ACCESS_TOKEN).toBeDefined();
  });
});
