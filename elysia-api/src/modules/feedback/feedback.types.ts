export type FeedbackType = "BUG_REPORT" | "FEEDBACK" | "FEATURE_REQUEST" | "OTHER";
export type FeedbackSeverity = "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";

export interface CreateFeedbackDto {
  type: FeedbackType;
  subject: string;
  description: string;
  severity?: FeedbackSeverity;
  rating?: number;
  contactEmail?: string;
  appVersion?: string;
  deviceInfo?: string;
}

export interface FeedbackUserContext {
  userId: string;
  userCode?: string;
  displayName?: string;
  fullName?: string;
  email?: string;
}

export interface FeedbackResponse {
  success: boolean;
  message: string;
  deliveredToDiscord: boolean;
}
