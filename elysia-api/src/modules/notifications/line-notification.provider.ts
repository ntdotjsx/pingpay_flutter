import {
  NotificationProvider,
  NotificationResult,
} from "./notification-provider.interface";
import { FormattedNotificationMessage } from "./notification-template.service";

export class LineNotificationProvider implements NotificationProvider {
  readonly name = "line";
  private mockSentMessages: Array<{ recipientId: string; text: string; timestamp: Date }> = [];
  private shouldFail = false;
  private failAfterAttempts = 0;
  private currentAttemptCount = 0;

  setSimulateFailure(fail: boolean, failAfterAttempts = 0) {
    this.shouldFail = fail;
    this.failAfterAttempts = failAfterAttempts;
    this.currentAttemptCount = 0;
  }

  getSentMessages() {
    return [...this.mockSentMessages];
  }

  clear() {
    this.mockSentMessages = [];
    this.shouldFail = false;
    this.failAfterAttempts = 0;
    this.currentAttemptCount = 0;
  }

  /**
   * 5.8 Send LINE Push Message to user
   * Checks if user has a valid lineUserId (from auth_identities).
   * If not linked, gracefully skips without crashing.
   */
  async send(
    recipientUserId: string,
    recipientLineId: string | null,
    message: FormattedNotificationMessage
  ): Promise<NotificationResult> {
    if (!recipientLineId) {
      return {
        success: false,
        provider: this.name,
        recipientId: recipientUserId,
        skippedReason: "NO_LINE_ID: User has not linked a LINE account.",
      };
    }

    this.currentAttemptCount++;

    if (this.shouldFail) {
      if (this.failAfterAttempts === 0 || this.currentAttemptCount <= this.failAfterAttempts) {
        return {
          success: false,
          provider: this.name,
          recipientId: recipientLineId,
          error: "LINE_API_ERROR: 500 Internal Server Error (Simulated API Outage)",
        };
      }
    }

    const token = process.env.LINE_CHANNEL_ACCESS_TOKEN;

    // If real LINE Channel Access Token is provided, call LINE Messaging API
    if (token) {
      try {
        const response = await fetch("https://api.line.me/v2/bot/message/push", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            to: recipientLineId,
            messages: [{ type: "text", text: message.body }],
          }),
        });

        if (!response.ok) {
          const errBody = await response.text();
          return {
            success: false,
            provider: this.name,
            recipientId: recipientLineId,
            error: `LINE_API_ERROR: HTTP ${response.status} - ${errBody}`,
          };
        }

        const resData = await response.json().catch(() => ({}));
        const providerMessageId = (response.headers.get("x-line-request-id") as string) || `line-msg-${crypto.randomUUID()}`;

        return {
          success: true,
          provider: this.name,
          recipientId: recipientLineId,
          providerMessageId,
          responsePayload: resData,
        };
      } catch (err: any) {
        return {
          success: false,
          provider: this.name,
          recipientId: recipientLineId,
          error: `LINE_NETWORK_ERROR: ${err.message || String(err)}`,
        };
      }
    }

    // Default Mock Mode when running in local dev / test without token
    const providerMessageId = `line-msg-${crypto.randomUUID()}`;
    this.mockSentMessages.push({
      recipientId: recipientLineId,
      text: message.body,
      timestamp: new Date(),
    });

    return {
      success: true,
      provider: this.name,
      recipientId: recipientLineId,
      providerMessageId,
      responsePayload: { status: 200, message: "OK (Mock Delivered)", providerMessageId },
    };
  }
}

export const defaultLineNotificationProvider = new LineNotificationProvider();
