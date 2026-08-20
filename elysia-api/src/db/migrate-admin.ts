import postgres from 'postgres';
import { env } from '../config/env';

async function run() {
  const sql = postgres(env.DATABASE_URL, { max: 1 });

  try {
    console.log("Ensuring admin enums and tables exist in database...");

    await sql.unsafe(`
      DO $$ BEGIN
        CREATE TYPE "public"."user_role" AS ENUM('user', 'developer');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."account_status" AS ENUM('active', 'suspended', 'banned');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."admin_action_type" AS ENUM('view_transactions', 'view_logs', 'suspend_account', 'ban_account', 'unsuspend_account', 'flag_suspicious', 'resolve_dispute');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;

      DO $$ BEGIN
        CREATE TYPE "public"."dispute_status" AS ENUM('open', 'under_review', 'resolved_paid', 'resolved_written_off', 'resolved_rejected');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;

      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "role" "public"."user_role" DEFAULT 'user' NOT NULL;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "account_status" "public"."account_status" DEFAULT 'active' NOT NULL;
      ALTER TABLE IF EXISTS "users" ADD COLUMN IF NOT EXISTS "suspended_until" timestamp;

      CREATE TABLE IF NOT EXISTS "admin_action_logs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "admin_id" uuid NOT NULL REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action,
        "action_type" "public"."admin_action_type" NOT NULL,
        "target_user_id" uuid REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action,
        "reason" text,
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );

      CREATE INDEX IF NOT EXISTS "admin_action_logs_admin_idx" ON "admin_action_logs" USING btree ("admin_id");
      CREATE INDEX IF NOT EXISTS "admin_action_logs_target_user_idx" ON "admin_action_logs" USING btree ("target_user_id");

      CREATE TABLE IF NOT EXISTS "activity_logs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action,
        "action" varchar(64) NOT NULL,
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );

      CREATE INDEX IF NOT EXISTS "activity_logs_user_idx" ON "activity_logs" USING btree ("user_id");
      CREATE INDEX IF NOT EXISTS "activity_logs_created_at_idx" ON "activity_logs" USING btree ("created_at");

      CREATE TABLE IF NOT EXISTS "suspicious_activity_logs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "user_id" uuid REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action,
        "type" varchar(64) NOT NULL,
        "description" text NOT NULL,
        "metadata" jsonb,
        "created_at" timestamp DEFAULT now() NOT NULL
      );

      CREATE INDEX IF NOT EXISTS "suspicious_logs_user_idx" ON "suspicious_activity_logs" USING btree ("user_id");
      CREATE INDEX IF NOT EXISTS "suspicious_logs_type_idx" ON "suspicious_activity_logs" USING btree ("type");

      CREATE TABLE IF NOT EXISTS "disputes" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
        "bill_item_id" uuid NOT NULL REFERENCES "public"."bill_items"("id") ON DELETE cascade ON UPDATE no action,
        "raised_by_id" uuid NOT NULL REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action,
        "reason" text NOT NULL,
        "status" "public"."dispute_status" DEFAULT 'open' NOT NULL,
        "resolved_by_id" uuid REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action,
        "resolution_note" text,
        "resolved_at" timestamp,
        "created_at" timestamp DEFAULT now() NOT NULL
      );

      CREATE INDEX IF NOT EXISTS "disputes_bill_item_idx" ON "disputes" USING btree ("bill_item_id");
      CREATE INDEX IF NOT EXISTS "disputes_status_idx" ON "disputes" USING btree ("status");
    `);

    console.log("Admin tables and enums verified & created successfully.");
  } catch (err) {
    console.error("Migration error:", err);
    process.exit(1);
  } finally {
    await sql.end();
  }
}

run();
