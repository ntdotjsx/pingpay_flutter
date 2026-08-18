import { Elysia } from "elysia";
import { onboardingGuard } from "../../../../middleware/auth";
import { FriendService } from "../../../../modules/friends/friend.service";
import { SearchUserQuerySchema } from "../../../../modules/friends/friend.types";

export default new Elysia()
  .use(onboardingGuard)
  .onBeforeHandle(({ onboardingState, set }) => {
    if (onboardingState !== "COMPLETED") {
      set.status = 403;
      return { error: "Profile not completed. Cannot access user search." };
    }
  })
  .get("/search", async ({ query, user, set }) => {
    try {
      const result = await FriendService.searchUser(query.userCode, user.id);
      if (!result) {
        set.status = 404;
        return { success: false, error: "USER_NOT_FOUND" };
      }
      return { success: true, data: { user: result } };
    } catch (e: any) {
      set.status = 400;
      return { success: false, error: e.message };
    }
  }, {
    query: SearchUserQuerySchema,
    detail: { 
      tags: ["Users"], 
      summary: "Search Users", 
      description: "Search for a specific user using their exact public userCode." 
    }
  });
