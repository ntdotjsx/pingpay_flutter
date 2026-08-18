import { FormattedNotificationMessage } from "./notification-template.service";

export interface NotificationResult {
  success: boolean;
  provider: string;
  recipientId: string;
  providerMessageId?: string;
  responsePayload?: any;
  error?: string;
  skippedReason?: string;
}

export interface NotificationProvider {
  name: string;
  send(
    recipientUserId: string,
    recipientProviderId: string | null,
    message: FormattedNotificationMessage
  ): Promise<NotificationResult>;
}
