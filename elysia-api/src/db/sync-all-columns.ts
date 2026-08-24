import postgres from "postgres";
import { env } from "../config/env";

async function run() {
  const sql = postgres(env.DATABASE_URL, { max: 1 });

  try {
    console.log("Checking and syncing all schema tables and columns to database...");

    await sql.unsafe(`
      -- Enums
      DO $$ BEGIN
        CREATE TYPE "public"."friend_status" AS ENUM('pending', 'accepted', 'blocked', 'rejected', 'cancelled');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."bill_status" AS ENUM('unpaid', 'partially_paid', 'fully_paid', 'partially_written_off', 'fully_written_off', 'cancelled');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."bill_item_status" AS ENUM('unpaid', 'partially_paid', 'paid', 'written_off');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."payment_method" AS ENUM('full', 'installment');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."payment_channel" AS ENUM('promptpay_qr', 'bank_transfer', 'cash');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."promptpay_id_type" AS ENUM('mobile_number', 'national_id', 'ewallet_id');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."payment_status" AS ENUM('pending_verification', 'verification_failed', 'pending_owner_confirmation', 'confirmed', 'rejected', 'cancelled', 'refunded');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."edit_action" AS ENUM('bill_created', 'bill_amount_edited', 'bill_item_edited', 'debt_written_off', 'bill_cancelled', 'friend_added', 'friend_removed');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."transaction_type" AS ENUM('debt_created', 'debt_adjusted', 'payment', 'refund', 'write_off');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."account_status" AS ENUM('active', 'suspended', 'banned');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."user_role" AS ENUM('user', 'developer');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."admin_action_type" AS ENUM('view_transactions', 'view_logs', 'suspend_account', 'ban_account', 'unsuspend_account', 'flag_suspicious', 'resolve_dispute');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."dispute_status" AS ENUM('open', 'under_review', 'resolved_paid', 'resolved_written_off', 'resolved_rejected');
      EXCEPTION WHEN duplicate_object THEN null; END $$;

      -- 1. users table columns
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "first_name" varchar(64);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "last_name" varchar(64);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "bank_name" varchar(64);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "bank_code" varchar(32);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "truemoney_phone" varchar(32);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "reward_points" integer DEFAULT 0 NOT NULL;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "shipping_address" text;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "shipping_phone" varchar(32);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "shipping_recipient_name" varchar(128);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "role" "public"."user_role" DEFAULT 'user' NOT NULL;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "account_status" "public"."account_status" DEFAULT 'active' NOT NULL;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "suspended_until" timestamp;

      -- 2. bill_items table columns
      ALTER TABLE IF EXISTS "bill_items" ADD COLUMN IF NOT EXISTS "is_acknowledged" boolean DEFAULT false NOT NULL;
      ALTER TABLE IF EXISTS "bill_items" ADD COLUMN IF NOT EXISTS "acknowledged_at" timestamp;
      ALTER TABLE IF EXISTS "bill_items" ADD COLUMN IF NOT EXISTS "is_locked" boolean DEFAULT false NOT NULL;

      -- 3. bills table columns
      ALTER TABLE IF EXISTS "bills" ADD COLUMN IF NOT EXISTS "original_total_amount" numeric(12, 2);
      ALTER TABLE IF EXISTS "bills" ADD COLUMN IF NOT EXISTS "items_breakdown" jsonb;
      ALTER TABLE IF EXISTS "bills" ADD COLUMN IF NOT EXISTS "cancelled_at" timestamp;

      -- 4. payments table columns
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "confirmed_by_owner_id" uuid REFERENCES "users"("id") ON DELETE SET NULL;
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "rejected_at" timestamp;
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "rejected_by_id" uuid REFERENCES "users"("id") ON DELETE SET NULL;
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "rejected_reason" text;

      -- 5. reward_items table
      CREATE TABLE IF NOT EXISTS "reward_items" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "title" varchar(128) NOT NULL,
        "description" text,
        "points_cost" integer NOT NULL,
        "category" varchar(64) DEFAULT 'physical',
        "image_url" text,
        "in_stock" integer DEFAULT 0 NOT NULL,
        "is_active" boolean DEFAULT true NOT NULL,
        "created_at" timestamp DEFAULT now() NOT NULL,
        "updated_at" timestamp DEFAULT now() NOT NULL
      );

      -- 6. reward_redemptions table
      CREATE TABLE IF NOT EXISTS "reward_redemptions" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE cascade,
        "reward_item_id" uuid NOT NULL REFERENCES "reward_items"("id") ON DELETE restrict,
        "points_spent" integer NOT NULL,
        "status" varchar(32) DEFAULT 'pending_delivery' NOT NULL,
        "recipient_name" varchar(128) NOT NULL,
        "phone_number" varchar(32) NOT NULL,
        "shipping_address" text NOT NULL,
        "tracking_number" varchar(64),
        "created_at" timestamp DEFAULT now() NOT NULL,
        "updated_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "reward_redemptions_user_idx" ON "reward_redemptions" USING btree ("user_id");

      -- 7. payment_verifications table
      CREATE TABLE IF NOT EXISTS "payment_verifications" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "payment_id" uuid NOT NULL REFERENCES "payments"("id") ON DELETE cascade,
        "provider" varchar(32) DEFAULT 'easyslip' NOT NULL,
        "status" varchar(32) NOT NULL,
        "provider_reference" varchar(128),
        "verified_amount" numeric(12, 2),
        "sender_info" jsonb,
        "receiver_info" jsonb,
        "failure_code" varchar(64),
        "failure_message" text,
        "raw_response" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "payment_verifications_payment_idx" ON "payment_verifications" USING btree ("payment_id");

      -- 8. device_tokens table
      CREATE TABLE IF NOT EXISTS "device_tokens" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "token" text NOT NULL UNIQUE,
        "platform" varchar(32) DEFAULT 'android' NOT NULL,
        "device_name" varchar(128),
        "device_model" varchar(128),
        "device_brand" varchar(64),
        "os_version" varchar(64),
        "app_version" varchar(64),
        "created_at" timestamp DEFAULT now() NOT NULL,
        "updated_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "device_tokens_user_idx" ON "device_tokens" USING btree ("user_id");

      -- 9. otp_verifications table
      CREATE TABLE IF NOT EXISTS "otp_verifications" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "email" varchar(255) NOT NULL,
        "otp_hash" text NOT NULL,
        "purpose" varchar(32) DEFAULT 'pin_reset' NOT NULL,
        "attempts" integer DEFAULT 0 NOT NULL,
        "max_attempts" integer DEFAULT 5 NOT NULL,
        "expires_at" timestamp NOT NULL,
        "verified_at" timestamp,
        "created_at" timestamp DEFAULT now() NOT NULL,
        "updated_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "otp_verifications_user_idx" ON "otp_verifications" USING btree ("user_id");
      CREATE INDEX IF NOT EXISTS "otp_verifications_email_idx" ON "otp_verifications" USING btree ("email");

      -- 10. security_events table
      CREATE TABLE IF NOT EXISTS "security_events" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL,
        "event" varchar(64) NOT NULL,
        "ip_address" varchar(64),
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "security_events_user_idx" ON "security_events" USING btree ("user_id");

      -- 11. admin_action_logs table
      CREATE TABLE IF NOT EXISTS "admin_action_logs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "admin_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE restrict,
        "action_type" "public"."admin_action_type" NOT NULL,
        "target_user_id" uuid REFERENCES "users"("id") ON DELETE set null,
        "reason" text,
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "admin_action_logs_admin_idx" ON "admin_action_logs" USING btree ("admin_id");
      CREATE INDEX IF NOT EXISTS "admin_action_logs_target_user_idx" ON "admin_action_logs" USING btree ("target_user_id");

      -- 12. activity_logs table
      CREATE TABLE IF NOT EXISTS "activity_logs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid REFERENCES "users"("id") ON DELETE set null,
        "action" varchar(64) NOT NULL,
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "activity_logs_user_idx" ON "activity_logs" USING btree ("user_id");
      CREATE INDEX IF NOT EXISTS "activity_logs_created_at_idx" ON "activity_logs" USING btree ("created_at");

      -- 13. suspicious_activity_logs table
      CREATE TABLE IF NOT EXISTS "suspicious_activity_logs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid REFERENCES "users"("id") ON DELETE set null,
        "type" varchar(64) NOT NULL,
        "description" text NOT NULL,
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "suspicious_logs_user_idx" ON "suspicious_activity_logs" USING btree ("user_id");
      CREATE INDEX IF NOT EXISTS "suspicious_logs_type_idx" ON "suspicious_activity_logs" USING btree ("type");

      -- 14. disputes table
      CREATE TABLE IF NOT EXISTS "disputes" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "bill_item_id" uuid NOT NULL REFERENCES "bill_items"("id") ON DELETE cascade,
        "raised_by_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE restrict,
        "reason" text NOT NULL,
        "status" "public"."dispute_status" DEFAULT 'open' NOT NULL,
        "resolved_by_id" uuid REFERENCES "users"("id") ON DELETE set null,
        "resolution_note" text,
        "resolved_at" timestamp,
        "created_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "disputes_bill_item_idx" ON "disputes" USING btree ("bill_item_id");
      CREATE INDEX IF NOT EXISTS "disputes_status_idx" ON "disputes" USING btree ("status");
    `);

    console.log("Successfully synced and updated all database tables and columns!");
  } catch (err) {
    console.error("Migration error:", err);
    process.exit(1);
  } finally {
    await sql.end();
  }
}

run();
