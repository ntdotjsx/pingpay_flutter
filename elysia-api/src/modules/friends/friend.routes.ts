import { Elysia, t } from "elysia";
import { onboardingGuard } from "../../middleware/auth";
import { FriendService } from "./friend.service";
import { 
  SearchUserQuerySchema, 
  SendFriendRequestSchema, 
  PaginationQuerySchema,
  RemoveFriendSchema
} from "./friend.types";

export const friendRoutes = new Elysia()
  .use(onboardingGuard)
  // Ensure only fully completed profiles can access these routes
  .onBeforeHandle(({ onboardingState, set }) => {
    if (onboardingState !== "COMPLETED") {
      set.status = 403;
      return { error: "Profile not completed. Cannot access friend features." };
    }
  })
  .get("/", async ({ query, user }) => {
    const limit = query.limit ? parseInt(query.limit as string, 10) : 20;
    const items = await FriendService.getFriends(user.id, limit);
    return { success: true, data: { items } };
  }, {
    query: PaginationQuerySchema,
    detail: { 
      tags: ["Friends"], 
      summary: "Get Friends List", 
      description: "Retrieve a paginated list of the current user's accepted friends." 
    }
  })
  .post("/requests", async ({ body, user, set }) => {
    try {
      const request = await FriendService.sendFriendRequest(body.userCode, user.id);
      return { success: true, data: request };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    body: SendFriendRequestSchema,
    detail: { 
      tags: ["Friends"], 
      summary: "Send Friend Request", 
      description: "Send a new friend request to another user using their public userCode." 
    }
  })
  .get("/requests/incoming", async ({ query, user }) => {
    const limit = query.limit ? parseInt(query.limit as string, 10) : 20;
    const items = await FriendService.getIncomingRequests(user.id, limit);
    return { success: true, data: { items } };
  }, {
    query: PaginationQuerySchema,
    detail: { 
      tags: ["Friends"], 
      summary: "Get Incoming Requests", 
      description: "Retrieve a paginated list of pending friend requests sent to the current user." 
    }
  })
  .get("/requests/outgoing", async ({ query, user }) => {
    const limit = query.limit ? parseInt(query.limit as string, 10) : 20;
    const items = await FriendService.getOutgoingRequests(user.id, limit);
    return { success: true, data: { items } };
  }, {
    query: PaginationQuerySchema,
    detail: { 
      tags: ["Friends"], 
      summary: "Get Outgoing Requests", 
      description: "Retrieve a paginated list of pending friend requests sent by the current user." 
    }
  })
  .post("/requests/:requestId/accept", async ({ params: { requestId }, user, set }) => {
    try {
      const friendship = await FriendService.acceptRequest(requestId, user.id);
      return { success: true, data: friendship };
    } catch (e: any) {
      set.status = e.message === "FORBIDDEN" ? 403 : 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ requestId: t.String() }),
    detail: { 
      tags: ["Friends"], 
      summary: "Accept Friend Request", 
      description: "Accept a pending incoming friend request." 
    }
  })
  .post("/requests/:requestId/reject", async ({ params: { requestId }, user, set }) => {
    try {
      const friendship = await FriendService.rejectRequest(requestId, user.id);
      return { success: true, data: friendship };
    } catch (e: any) {
      set.status = e.message === "FORBIDDEN" ? 403 : 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ requestId: t.String() }),
    detail: { 
      tags: ["Friends"], 
      summary: "Reject Friend Request", 
      description: "Reject a pending incoming friend request." 
    }
  })
  .post("/requests/:requestId/cancel", async ({ params: { requestId }, user, set }) => {
    try {
      const friendship = await FriendService.cancelRequest(requestId, user.id);
      return { success: true, data: friendship };
    } catch (e: any) {
      set.status = e.message === "FORBIDDEN" ? 403 : 400;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ requestId: t.String() }),
    detail: { 
      tags: ["Friends"], 
      summary: "Cancel Friend Request", 
      description: "Cancel a pending outgoing friend request that hasn't been accepted yet." 
    }
  })
  .get("/:friendshipId", async ({ params: { friendshipId }, user, set }) => {
    try {
      const details = await FriendService.getFriendDetails(friendshipId, user.id);
      return { success: true, data: details };
    } catch (e: any) {
      set.status = e.message === "FORBIDDEN" ? 403 : 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ friendshipId: t.String() }),
    detail: { 
      tags: ["Friends"], 
      summary: "Get Friendship Details", 
      description: "Retrieve specific details about an active friendship." 
    }
  })
  .get("/:friendshipId/removal-check", async ({ params: { friendshipId }, user, set }) => {
    try {
      const check = await FriendService.checkRemoval(friendshipId, user.id);
      return { success: true, data: check };
    } catch (e: any) {
      set.status = e.message === "FORBIDDEN" ? 403 : 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ friendshipId: t.String() }),
    detail: { 
      tags: ["Friends"], 
      summary: "Check Removal Eligibility", 
      description: "Check if a friend can be removed safely or if there is an unsettled debt." 
    }
  })
  .post("/:friendshipId/remove", async ({ params: { friendshipId }, body, user, set }) => {
    try {
      const confirm = body?.confirmOutstandingDebt ?? false;
      const result = await FriendService.removeFriend(friendshipId, user.id, confirm);
      return { success: true, data: result };
    } catch (e: any) {
      if (e.message === "FORBIDDEN") set.status = 403;
      else if (e.message === "OUTSTANDING_DEBT_CONFIRMATION_REQUIRED") set.status = 400;
      else set.status = 404;
      return { success: false, error: e.message };
    }
  }, {
    params: t.Object({ friendshipId: t.String() }),
    body: RemoveFriendSchema,
    detail: { 
      tags: ["Friends"], 
      summary: "Remove Friend", 
      description: "Remove an active friend. Requires 'force' flag if there is unsettled debt." 
    }
  });
