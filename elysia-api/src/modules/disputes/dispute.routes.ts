import { Elysia, t } from "elysia";
import { DisputeService } from "./dispute.service";

const disputeService = new DisputeService();

export const disputeRoutes = new Elysia({ prefix: "/disputes" })
  .post("/", async ({ body, user, set }: { body: any; user: any; set: any }) => {
    try {
      const dispute = await disputeService.createDispute(user.id, body);
      set.status = 201;
      return { success: true, data: dispute };
    } catch (e: any) {
      if (e.message?.includes("NOT_FOUND")) {
        set.status = 404;
      } else if (e.message?.includes("FORBIDDEN")) {
        set.status = 403;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    body: t.Object({
      billItemId: t.String(),
      reason: t.String(),
      evidenceUrl: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Disputes"],
      summary: "Raise a dispute on a bill item",
      description: "Debtor raises a dispute with reason and optional proof.",
    },
  })
  .get("/", async ({ user, set }: { user: any; set: any }) => {
    try {
      const list = await disputeService.getUserDisputes(user.id);
      return { success: true, data: list };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    detail: {
      tags: ["Disputes"],
      summary: "List user disputes",
      description: "Lists disputes where user is debtor or creditor.",
    },
  })
  .get("/:id", async ({ params, user, set }: { params: any; user: any; set: any }) => {
    try {
      const dispute = await disputeService.getDisputeDetail(user.id, params.id);
      return { success: true, data: dispute };
    } catch (e: any) {
      if (e.message?.includes("NOT_FOUND")) {
        set.status = 404;
      } else if (e.message?.includes("FORBIDDEN")) {
        set.status = 403;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({
      id: t.String(),
    }),
    detail: {
      tags: ["Disputes"],
      summary: "Get dispute details",
      description: "Retrieves dispute info with debtor and creditor evidence.",
    },
  })
  .post("/:id/evidence", async ({ params, body, user, set }: { params: any; body: any; user: any; set: any }) => {
    try {
      const updated = await disputeService.submitCreditorEvidence(user.id, params.id, body);
      return { success: true, data: updated };
    } catch (e: any) {
      if (e.message?.includes("NOT_FOUND")) {
        set.status = 404;
      } else if (e.message?.includes("FORBIDDEN")) {
        set.status = 403;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({
      id: t.String(),
    }),
    body: t.Object({
      note: t.Optional(t.String()),
      evidenceUrl: t.Optional(t.String()),
    }),
    detail: {
      tags: ["Disputes"],
      summary: "Submit creditor counter-evidence",
      description: "Creditor submits counter-explanation and/or proof for an open dispute.",
    },
  });
