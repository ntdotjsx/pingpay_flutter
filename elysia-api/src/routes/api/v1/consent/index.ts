import { Elysia, t } from "elysia";
import { db } from "../../../../db";
import { consentRecords, users } from "../../../../db/schema";
import { eq } from "drizzle-orm";
import jwt from "jsonwebtoken";
import { env } from "../../../../config/env";

const CURRENT_POLICY_VERSION = "v1.0.0";

const requireAuth = (app: Elysia) =>
  app.derive(async ({ cookie: { access_token }, set }) => {
    if (!access_token.value) {
      set.status = 401;
      throw new Error("Unauthorized");
    }
    try {
      const decoded = jwt.verify(access_token.value, env.JWT_ACCESS_SECRET) as { userId: string };
      return { userId: decoded.userId };
    } catch {
      set.status = 401;
      throw new Error("Unauthorized");
    }
  });

export default new Elysia()
  .use(requireAuth)
  .get("/current", async ({ userId }) => {
    const records = await db.query.consentRecords.findMany({
      where: eq(consentRecords.userId, userId),
      orderBy: (records, { desc }) => [desc(records.acceptedAt)],
      limit: 1,
    });

    const hasAcceptedCurrent = records.length > 0 && records[0].policyVersion === CURRENT_POLICY_VERSION;

    return {
      policyVersion: CURRENT_POLICY_VERSION,
      hasAccepted: hasAcceptedCurrent,
      lastAcceptedAt: records.length > 0 ? records[0].acceptedAt : null,
    };
  }, { detail: { tags: ["Profile & Consent"], summary: "Get current consent status" } })
  .post("/accept", async ({ userId }) => {
    await db.insert(consentRecords).values({
      userId,
      policyVersion: CURRENT_POLICY_VERSION,
    });

    return { success: true, policyVersion: CURRENT_POLICY_VERSION };
  }, { detail: { tags: ["Profile & Consent"], summary: "Accept PDPA consent" } });
