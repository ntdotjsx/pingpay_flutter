export interface NotificationMessage {
  userId: string;
  billId: string;
  billTitle: string;
  actorName: string;
  type: "update" | "write_off" | "adjustment";
  oldAmount: string;
  newAmount: string;
  reason?: string;
  timestamp: Date;
}

export interface NotificationService {
  notify(message: NotificationMessage): Promise<boolean>;
}

export class FakeLineNotificationService implements NotificationService {
  private sentNotifications: NotificationMessage[] = [];
  private shouldFail = false;

  setShouldFail(fail: boolean) {
    this.shouldFail = fail;
  }

  async notify(message: NotificationMessage): Promise<boolean> {
    if (this.shouldFail) {
      console.warn(`[FakeLineNotificationService] Simulated LINE API delivery failure for user: ${message.userId}`);
      return false;
    }
    this.sentNotifications.push(message);
    console.log(`[FakeLineNotificationService] Sent LINE notification to ${message.userId}:
📋 Bill ${message.type === "write_off" ? "Debt write-off" : "updated"}
${message.billTitle}
Amount: ${message.oldAmount} THB -> ${message.newAmount} THB
Changed by: ${message.actorName}
Time: ${message.timestamp.toISOString()}`);
    return true;
  }

  getSentNotifications(): NotificationMessage[] {
    return [...this.sentNotifications];
  }

  clear() {
    this.sentNotifications = [];
    this.shouldFail = false;
  }
}

export const defaultNotificationService = new FakeLineNotificationService();
