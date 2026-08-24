import { db } from "../../db";
import { activityLogs } from "../../db/schema";

export type ActivityAction =
  | "user_login"
  | "user_registered"
  | "pin_setup"
  | "pin_verified"
  | "profile_updated"
  | "consent_accepted"
  | "bill_created"
  | "bill_updated"
  | "bill_cancelled"
  | "debt_acknowledged"
  | "slip_uploaded"
  | "payment_confirmed"
  | "payment_rejected"
  | "friend_request_sent"
  | "friend_request_accepted"
  | "friend_removed"
  | "reward_redeemed";

export class ActivityService {
  /**
   * Safely records user activity in the background without throwing errors
   * that could disrupt client HTTP requests.
   */
  static async log(userId: string | null | undefined, action: ActivityAction | string, metadata?: Record<string, any>) {
    try {
      if (!userId) return;
      await db.insert(activityLogs).values({
        userId,
        action,
        metadata: metadata || {},
      });
    } catch (err: any) {
      console.warn(`[ActivityLogger] Failed to log activity ${action} for user ${userId}:`, err?.message || err);
    }
  }
}

export const logActivity = ActivityService.log;
