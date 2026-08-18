import { Static } from "elysia";
import { CreateBillSchema, EditBillSchema, EditBillItemSchema } from "./bill.schema";

export type CreateBillDTO = Static<typeof CreateBillSchema>;
export type EditBillDTO = Static<typeof EditBillSchema>;
export type EditBillItemDTO = Static<typeof EditBillItemSchema>;
