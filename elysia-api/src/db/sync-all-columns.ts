import postgres from "postgres";
import { env } from "../config/env";

async function run() {
  const sql = postgres(env.DATABASE_URL, { max: 1 });

  try {
    console.log("Checking and syncing all missing columns across all tables...");

    await sql.unsafe(`
      -- 1. bill_items missing columns
      ALTER TABLE IF EXISTS "bill_items" ADD COLUMN IF NOT EXISTS "is_acknowledged" boolean DEFAULT false NOT NULL;
      ALTER TABLE IF EXISTS "bill_items" ADD COLUMN IF NOT EXISTS "acknowledged_at" timestamp;

      -- 2. users missing columns
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "reward_points" integer DEFAULT 0 NOT NULL;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "shipping_address" text;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "shipping_phone" varchar(32);
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "shipping_recipient_name" varchar(128);

      -- 3. payments missing columns
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "confirmed_by_owner_id" uuid REFERENCES "users"("id") ON DELETE SET NULL;
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "rejected_at" timestamp;
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "rejected_by_id" uuid REFERENCES "users"("id") ON DELETE SET NULL;
      ALTER TABLE IF EXISTS "payments" ADD COLUMN IF NOT EXISTS "rejected_reason" text;

      -- 4. device_tokens table
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

      -- 5. otp_verifications table
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

      -- 6. security_events table
      CREATE TABLE IF NOT EXISTS "security_events" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL,
        "event" varchar(64) NOT NULL,
        "ip_address" varchar(64),
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );
      CREATE INDEX IF NOT EXISTS "security_events_user_idx" ON "security_events" USING btree ("user_id");
    `);

    console.log("Successfully synced all missing columns and tables!");
  } catch (err) {
    console.error("Migration error:", err);
    process.exit(1);
  } finally {
    await sql.end();
  }
}

run();
