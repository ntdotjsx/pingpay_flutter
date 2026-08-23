import { Elysia } from "elysia";
import { realtimeRoutes } from "../../realtime/realtime.routes";

export default new Elysia().use(realtimeRoutes);
