import { Elysia } from "elysia";
import { friendRoutes } from "../../../../modules/friends/friend.routes";

export default new Elysia().use(friendRoutes);
