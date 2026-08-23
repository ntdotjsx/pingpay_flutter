import { describe, expect, test } from "bun:test";
import { RealtimeService } from "../../../src/realtime/realtime.service";

function socket() {
  const messages: string[] = [];
  return {
    messages,
    ws: {
      send(message: string) {
        messages.push(message);
      },
    },
  };
}

describe("RealtimeService", () => {
  test("sends user-specific events only to connected target user", () => {
    const realtime = new RealtimeService();
    const userA = socket();
    const userB = socket();

    realtime.connect("user-a", userA.ws);
    realtime.connect("user-b", userB.ws);
    userA.messages.length = 0;
    userB.messages.length = 0;

    realtime.sendToUser(
      "user-b",
      realtime.makeEvent("friend.request.created", {
        requestId: "request-1",
        senderId: "user-a",
        receiverId: "user-b",
      })
    );

    expect(userA.messages).toHaveLength(0);
    expect(userB.messages).toHaveLength(1);
    expect(JSON.parse(userB.messages[0]).type).toBe("friend.request.created");
  });

  test("deduplicates send recipients across multiple ids", () => {
    const realtime = new RealtimeService();
    const userA = socket();

    realtime.connect("user-a", userA.ws);
    userA.messages.length = 0;

    realtime.sendToUsers(
      ["user-a", "user-a"],
      realtime.makeEvent("bill.created", { billId: "bill-1" })
    );

    expect(userA.messages).toHaveLength(1);
  });
});
