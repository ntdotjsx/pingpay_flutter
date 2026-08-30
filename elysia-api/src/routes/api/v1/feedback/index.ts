import { Elysia, t } from "elysia";
import { onboardingGuard } from "../../../../middleware/auth";
import { sendFeedbackToDiscord } from "../../../../modules/feedback/feedback.service";
import type { FeedbackType, FeedbackSeverity } from "../../../../modules/feedback/feedback.types";

export default new Elysia()
  .use(onboardingGuard)
  .post("/", async ({ user, body, set }) => {
    try {
      const result = await sendFeedbackToDiscord(
        {
          type: body.type as FeedbackType,
          subject: body.subject,
          description: body.description,
          severity: body.severity as FeedbackSeverity | undefined,
          rating: body.rating,
          contactEmail: body.contactEmail,
          appVersion: body.appVersion,
          deviceInfo: body.deviceInfo,
        },
        {
          userId: user.id,
          userCode: user.userCode || undefined,
          displayName: user.displayName || user.fullName || "User",
          fullName: user.fullName || undefined,
          email: user.email || undefined,
        }
      );

      return {
        success: true,
        message: result.message,
        data: {
          deliveredToDiscord: result.deliveredToDiscord,
        },
      };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    body: t.Object({
      type: t.Union([
        t.Literal("BUG_REPORT"),
        t.Literal("FEEDBACK"),
        t.Literal("FEATURE_REQUEST"),
        t.Literal("OTHER"),
      ]),
      subject: t.String({ minLength: 2, maxLength: 150 }),
      description: t.String({ minLength: 5, maxLength: 3000 }),
      severity: t.Optional(
        t.Union([
          t.Literal("LOW"),
          t.Literal("MEDIUM"),
          t.Literal("HIGH"),
          t.Literal("CRITICAL"),
        ])
      ),
      rating: t.Optional(t.Number({ minimum: 1, maximum: 5 })),
      contactEmail: t.Optional(t.String()),
      appVersion: t.Optional(t.String()),
      deviceInfo: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Feedback"],
      summary: "Send user feedback or bug report to Discord Webhook",
      description: "Directly forwards user feedback and bug reports to the team Discord channel. Strictly stateless (no DB storage).",
    },
  });
