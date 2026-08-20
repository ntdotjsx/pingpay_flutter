import { Elysia, t } from "elysia";
import { BillService } from "./bill.service";
import {
  CreateBillSchema,
  EditBillSchema,
  EditBillItemSchema,
  WriteOffRequestSchema,
  AdjustmentRequestSchema
} from "./bill.schema";

const billService = new BillService();

export const billRoutes = new Elysia()
  .post("/", async ({ body, user, set }) => {
    try {
      const bill = await billService.createBill(user.id, body);
      set.status = 201;
      return { success: true, data: bill };
    } catch (e: any) {
      if (e.message.includes("TOTAL_MISMATCH") || e.message.includes("INVALID_AMOUNT") || e.message.includes("DUPLICATE_PARTICIPANT")) {
        set.status = 400;
      } else if (e.message.includes("BILL_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 422;
      }
      return { success: false, error: e.message };
    }
  }, {
    body: CreateBillSchema,
    detail: {
      tags: ["Bills"],
      summary: "Create a new bill",
      description: "Creates a new bill manually with specified participants and allocation method."
    }
  })
  .post("/ocr", async ({ body, set }) => {
    try {
      const receipt = await billService.processOCRReceipt(body.receipt);
      return { success: true, data: receipt };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    body: t.Object({
      receipt: t.File({ description: "Receipt image file (JPEG, PNG, WEBP, HEIC)" })
    }),
    detail: {
      tags: ["Bills"],
      summary: "Extract bill data from receipt OCR",
      description: "Uploads a receipt image to extract merchant, total, and line items as a bill draft."
    }
  })
  .get("/", async ({ user, set }) => {
    try {
      const bills = await billService.getMyBills(user.id);
      return { success: true, data: bills };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    detail: {
      tags: ["Bills"],
      summary: "Get all bills created by the current user",
      description: "Retrieves complete list of bills created by the authenticated user."
    }
  })
  .get("/:id", async ({ params: { id }, set }) => {
    try {
      const bill = await billService.getBill(id);
      return { success: true, data: bill };
    } catch (e: any) {
      set.status = 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    detail: {
      tags: ["Bills"],
      summary: "Get bill details by ID",
      description: "Retrieves complete bill details including items and participants."
    }
  })
  .patch("/:id", async ({ params: { id }, body, user, set }) => {
    try {
      const bill = await billService.editBill(user.id, id, body);
      return { success: true, data: bill };
    } catch (e: any) {
      if (e.message.includes("Unauthorized")) {
        set.status = 403;
      } else if (e.message.includes("PAID_DEBT_LOCKED")) {
        set.status = 409;
      } else if (e.message.includes("BILL_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: EditBillSchema,
    detail: {
      tags: ["Bills"],
      summary: "Edit bill details",
      description: "Updates bill title, description, or total amount if unpaid."
    }
  })
  .patch("/:id/participants/:participantId", async ({ params: { id, participantId }, body, user, set }) => {
    try {
      const bill = await billService.editBillItem(user.id, id, participantId, body.amount);
      return { success: true, data: bill };
    } catch (e: any) {
      if (e.message.includes("Unauthorized")) {
        set.status = 403;
      } else if (e.message.includes("PAID_DEBT_LOCKED")) {
        set.status = 409;
      } else if (e.message.includes("BILL_NOT_FOUND") || e.message.includes("PARTICIPANT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({
      id: t.String({ format: "uuid" }),
      participantId: t.String()
    }),
    body: EditBillItemSchema,
    detail: {
      tags: ["Bills"],
      summary: "Edit individual participant amount",
      description: "Modifies a participant's debt amount and automatically redistributes remaining debt among other unpaid participants."
    }
  })
  .post("/:id/write-offs", async ({ params: { id }, body, user, set }) => {
    try {
      const result = await billService.writeOffDebt(user.id, id, body);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("Unauthorized")) {
        set.status = 403;
      } else if (e.message.includes("INSUFFICIENT_REMAINING_DEBT") || e.message.includes("INVALID_WRITE_OFF")) {
        set.status = 422;
      } else if (e.message.includes("BILL_NOT_FOUND") || e.message.includes("PARTICIPANT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: WriteOffRequestSchema,
    detail: {
      tags: ["Bills"],
      summary: "Write off participant debt",
      description: "Allows the bill owner to perform full or partial write-offs for specific participants without affecting paid revenue."
    }
  })
  .post("/:id/adjustments", async ({ params: { id }, body, user, set }) => {
    try {
      const result = await billService.adjustPaidDebt(user.id, id, body);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("Unauthorized")) {
        set.status = 403;
      } else if (e.message.includes("BILL_NOT_FOUND") || e.message.includes("PARTICIPANT_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: AdjustmentRequestSchema,
    detail: {
      tags: ["Bills"],
      summary: "Adjust paid debt (Refund or Additional Debt)",
      description: "Creates an adjustment or refund transaction for already-paid debts without modifying original payment records."
    }
  })
  .delete("/:id", async ({ params: { id }, body, user, set }) => {
    try {
      const reason = (body as any)?.reason;
      const result = await billService.cancelBill(user.id, id, reason);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message.includes("Unauthorized")) {
        set.status = 403;
      } else if (e.message.includes("BILL_NOT_FOUND")) {
        set.status = 404;
      } else {
        set.status = 400;
      }
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ id: t.String({ format: "uuid" }) }),
    body: t.Optional(t.Object({ reason: t.Optional(t.String()) })),
    detail: {
      tags: ["Bills"],
      summary: "Cancel bill and write off outstanding debts",
      description: "Cancels a bill and marks all unpaid items as written off, clearing them from receivables."
    }
  });
