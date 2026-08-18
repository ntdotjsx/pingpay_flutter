import { describe, it, expect } from "bun:test";

describe("Environment Validation", () => {
  it("should have loaded all environment variables", () => {
    expect(process.env.DATABASE_URL).toBeDefined();
    expect(process.env.LINE_CLIENT_ID).toBeDefined();
  });
});
