import { describe, it, expect, mock, beforeAll } from "bun:test";
import { app } from "../src/index";
import { edenTreaty } from "@elysiajs/eden";
import type { App } from "../src/index";
import jwt from "jsonwebtoken";

const api = edenTreaty<App>("http://localhost", {
  fetcher: (url, init) => app.handle(new Request(url.toString(), init as any))
});

globalThis.__mockState = "COMPLETED";

const validToken = jwt.sign({ userId: "test-user-id" }, process.env.JWT_ACCESS_SECRET || "access_secret");

mock.module("../src/db/index.ts", () => {
  return {
    db: {
      query: {
        users: {
          findFirst: mock().mockImplementation(async (query: any) => {
            // query.where might be a SQL object or an eq() representation.
            const queryStr = Bun.inspect(query) || "";
            if (queryStr.includes("USR-123")) {
              return {
                id: "test-friend-id",
                userCode: "USR-123",
                displayName: "Mock Friend",
                accountStatus: "active",
                role: "user"
              };
            }
            return {
              id: "test-user-id",
              userCode: "USR-MYCODE",
              displayName: "Test User",
              accountStatus: "active",
              role: "user",
              profileCompletedAt: new Date()
            };
          }),
          findMany: mock().mockImplementation(async () => {
            return [];
          })
        },
        consentRecords: {
          findFirst: mock().mockImplementation(async () => {
            return { id: "test-consent" };
          })
        },
        userCredentials: {
          findFirst: mock().mockImplementation(async () => {
            return { id: "test-cred", pinHash: "mock-hash" };
          })
        },
        friendships: {
          findFirst: mock().mockImplementation(async () => {
            return null; // Mock no existing relationship by default
          }),
          findMany: mock().mockImplementation(async () => {
            return [];
          })
        },
      },
      select: mock().mockReturnValue({
        from: mock().mockReturnValue({
          where: mock().mockReturnValue(Object.assign(
            Promise.resolve([]),
            {
              limit: mock().mockReturnValue(Promise.resolve([])),
              orderBy: mock().mockReturnValue(Promise.resolve([]))
            }
          )),
          innerJoin: mock().mockReturnValue({
            where: mock().mockReturnValue(Object.assign(
              Promise.resolve([]),
              {
                limit: mock().mockReturnValue(Promise.resolve([])),
                orderBy: mock().mockReturnValue(Promise.resolve([]))
              }
            ))
          })
        })
      }),
      transaction: mock().mockImplementation(async (cb: any) => {
        return cb({
          query: {
            friendships: {
              findFirst: mock().mockResolvedValue({
                id: "req-1",
                requesterId: "test-friend-id",
                addresseeId: "test-user-id",
                status: "pending",
                removedAt: null
              })
            }
          },
          insert: mock().mockReturnValue({
            values: mock().mockReturnValue({
              returning: mock().mockResolvedValue([{ id: "new-req" }])
            })
          }),
          update: mock().mockReturnValue({
            set: mock().mockReturnValue({
              where: mock().mockReturnValue({
                returning: mock().mockResolvedValue([{ id: "req-1", status: "accepted" }])
              })
            })
          }),
          select: mock().mockReturnValue({
            from: mock().mockReturnValue({
              where: mock().mockResolvedValue([])
            })
          })
        });
      }),
      insert: mock().mockReturnValue({
        values: mock().mockReturnValue({
          returning: mock().mockResolvedValue([{ id: "req-1" }])
        })
      }),
      update: mock().mockReturnValue({
        set: mock().mockReturnValue({
          where: mock().mockReturnValue({
            returning: mock().mockResolvedValue([{ id: "req-1", status: "rejected" }])
          })
        })
      })
    }
  };
});

describe("Friend Management API", () => {
  describe("1. User Search", () => {
    it("should find a user by userCode", async () => {
      const { status, data } = await api.api.v1.users.search.get({
        $query: { userCode: "USR-123" },
        $headers: { Cookie: `access_token=${validToken}` }
      });
      expect(status).toBe(200);
      expect(data?.success).toBe(true);
      expect(data?.data?.user?.displayName).toBe("Mock Friend");
    });
  });

  describe("2. Send Friend Request", () => {
    it("should send a friend request", async () => {
      const { status, data } = await api.api.v1.friends.requests.post(
        { userCode: "USR-123" },
        { headers: { Cookie: `access_token=${validToken}` } }
      );
      expect(status).toBe(200);
      expect(data?.success).toBe(true);
    });
  });

  describe("3. Accept Friend Request", () => {
    it("should accept a friend request", async () => {
      const { status, data } = await api.api.v1.friends.requests["req-1"].accept.post(
        null,
        { headers: { Cookie: `access_token=${validToken}` } }
      );
      expect(status).toBe(200);
      expect(data?.success).toBe(true);
    });
  });

  describe("4. Get Friends List", () => {
    it("should return empty list initially", async () => {
      const { status, data } = await api.api.v1.friends.get({
        $headers: { Cookie: `access_token=${validToken}` }
      });
      expect(status).toBe(200);
      expect(data?.success).toBe(true);
      expect(data?.data?.items).toBeInstanceOf(Array);
    });
  });
});
