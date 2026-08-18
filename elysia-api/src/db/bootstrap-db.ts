import { sql } from "drizzle-orm";
import { db } from "./index";

async function main() {
  console.log("Resetting and recreating entire DB schema cleanly...");

  await db.execute(sql`
    DROP SCHEMA public CASCADE;
    CREATE SCHEMA public;
    GRANT ALL ON SCHEMA public TO postgres;
    GRANT ALL ON SCHEMA public TO public;

    CREATE EXTENSION IF NOT EXISTS "pgcrypto";

    CREATE TYPE friend_status AS ENUM ('pending', 'accepted', 'blocked', 'rejected', 'cancelled');
    CREATE TYPE bill_status AS ENUM ('unpaid', 'partially_paid', 'fully_paid', 'partially_written_off', 'fully_written_off');
    CREATE TYPE bill_item_status AS ENUM ('unpaid', 'partially_paid', 'paid', 'written_off');
    CREATE TYPE payment_method AS ENUM ('full', 'installment');
    CREATE TYPE payment_channel AS ENUM ('promptpay_qr', 'bank_transfer', 'cash');
    CREATE TYPE promptpay_id_type AS ENUM ('mobile_number', 'national_id', 'ewallet_id');
    CREATE TYPE payment_status AS ENUM (
      'pending_verification',
      'verification_failed',
      'pending_owner_confirmation',
      'confirmed',
      'rejected',
      'cancelled',
      'refunded'
    );
    CREATE TYPE edit_action AS ENUM (
      'bill_created',
      'bill_amount_edited',
      'bill_item_edited',
      'debt_written_off',
      'bill_cancelled',
      'friend_added',
      'friend_removed'
    );
    CREATE TYPE transaction_type AS ENUM (
      'debt_created',
      'debt_adjusted',
      'payment',
      'refund',
      'write_off'
    );
    CREATE TYPE account_status AS ENUM ('active', 'suspended', 'banned');
    CREATE TYPE user_role AS ENUM ('user', 'developer');
    CREATE TYPE admin_action_type AS ENUM (
      'view_transactions',
      'view_logs',
      'suspend_account',
      'ban_account',
      'unsuspend_account',
      'flag_suspicious',
      'resolve_dispute'
    );
    CREATE TYPE dispute_status AS ENUM (
      'open',
      'under_review',
      'resolved_paid',
      'resolved_written_off',
      'resolved_rejected'
    );
    CREATE TYPE notification_event_type AS ENUM (
      'BILL_CREATED',
      'BILL_UPDATED',
      'BILL_WRITTEN_OFF',
      'PAYMENT_PENDING_CONFIRMATION',
      'PAYMENT_CONFIRMED',
      'PAYMENT_REJECTED',
      'DEBT_WEEKLY_REMINDER'
    );
    CREATE TYPE notification_status AS ENUM (
      'PENDING',
      'PROCESSING',
      'SENT',
      'FAILED',
      'CANCELLED',
      'SKIPPED'
    );

    CREATE TABLE users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_code VARCHAR(32) NOT NULL UNIQUE,
      display_name VARCHAR(128),
      full_name VARCHAR(128),
      address TEXT,
      phone_number VARCHAR(32),
      bank_account_number VARCHAR(32),
      prompt_pay_id VARCHAR(32),
      prompt_pay_id_type promptpay_id_type,
      prompt_pay_verified_at TIMESTAMP,
      avatar_url TEXT,
      profile_completed_at TIMESTAMP,
      role user_role NOT NULL DEFAULT 'user',
      account_status account_status NOT NULL DEFAULT 'active',
      suspended_until TIMESTAMP,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE user_credentials (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      pin_hash TEXT,
      failed_attempts INTEGER NOT NULL DEFAULT 0,
      locked_until TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE consent_records (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      policy_version VARCHAR(32) NOT NULL,
      accepted_at TIMESTAMP NOT NULL DEFAULT NOW(),
      ip_address VARCHAR(64)
    );

    CREATE TABLE auth_identities (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      provider VARCHAR(32) NOT NULL DEFAULT 'line',
      provider_user_id VARCHAR(128) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE auth_sessions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      refresh_token_hash TEXT NOT NULL,
      device_info TEXT,
      ip_address VARCHAR(64),
      expires_at TIMESTAMP NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE auth_oauth_states (
      state VARCHAR(64) PRIMARY KEY,
      code_verifier TEXT,
      redirect_uri TEXT,
      expires_at TIMESTAMP NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE groups (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name VARCHAR(128) NOT NULL,
      description TEXT,
      created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE group_members (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role VARCHAR(32) NOT NULL DEFAULT 'member',
      joined_at TIMESTAMP NOT NULL DEFAULT NOW(),
      UNIQUE (group_id, user_id)
    );

    CREATE TABLE friendships (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status friend_status NOT NULL DEFAULT 'pending',
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      responded_at TIMESTAMP,
      removed_at TIMESTAMP,
      UNIQUE (requester_id, addressee_id)
    );

    CREATE TABLE bills (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
      title VARCHAR(128),
      currency VARCHAR(3) NOT NULL DEFAULT 'THB',
      total_amount NUMERIC(12, 2) NOT NULL,
      receipt_image_url TEXT,
      ocr_raw_data JSONB,
      items_breakdown JSONB,
      status bill_status NOT NULL DEFAULT 'unpaid',
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      cancelled_at TIMESTAMP
    );

    CREATE TABLE bill_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      bill_id UUID NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
      debtor_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      original_amount NUMERIC(12, 2) NOT NULL,
      current_amount NUMERIC(12, 2) NOT NULL,
      amount_paid NUMERIC(12, 2) NOT NULL DEFAULT '0',
      amount_written_off NUMERIC(12, 2) NOT NULL DEFAULT '0',
      status bill_item_status NOT NULL DEFAULT 'unpaid',
      is_locked BOOLEAN NOT NULL DEFAULT false,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
      UNIQUE (bill_id, debtor_id)
    );

    CREATE TABLE payments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      bill_item_id UUID NOT NULL REFERENCES bill_items(id) ON DELETE CASCADE,
      payer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      method payment_method NOT NULL,
      channel payment_channel NOT NULL DEFAULT 'promptpay_qr',
      amount NUMERIC(12, 2) NOT NULL,
      installment_number INTEGER,
      prompt_pay_qr_payload TEXT,
      prompt_pay_qr_image_url TEXT,
      prompt_pay_qr_generated_at TIMESTAMP,
      slip_image_url TEXT,
      slip_hash VARCHAR(64),
      slip_ok_reference_id VARCHAR(128),
      slip_ok_verified_at TIMESTAMP,
      slip_ok_raw_response JSONB,
      status payment_status NOT NULL DEFAULT 'pending_verification',
      confirmed_by_owner_at TIMESTAMP,
      confirmed_by_owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
      rejected_at TIMESTAMP,
      rejected_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
      rejected_reason TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE payment_verifications (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
      provider VARCHAR(32) NOT NULL DEFAULT 'slipok',
      status VARCHAR(32) NOT NULL,
      provider_reference VARCHAR(128),
      verified_amount NUMERIC(12, 2),
      sender_info JSONB,
      receiver_info JSONB,
      failure_code VARCHAR(64),
      failure_message TEXT,
      raw_response JSONB,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE financial_transactions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      bill_id UUID NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
      bill_item_id UUID NOT NULL REFERENCES bill_items(id) ON DELETE CASCADE,
      type transaction_type NOT NULL,
      amount NUMERIC(12, 2) NOT NULL,
      currency VARCHAR(3) NOT NULL DEFAULT 'THB',
      reference_id VARCHAR(128),
      created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      metadata JSONB
    );

    CREATE TABLE edit_logs (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      action edit_action NOT NULL,
      bill_id UUID REFERENCES bills(id) ON DELETE CASCADE,
      bill_item_id UUID REFERENCES bill_items(id) ON DELETE CASCADE,
      performed_by_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      affected_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
      previous_value JSONB,
      new_value JSONB,
      note TEXT,
      notified_at TIMESTAMP,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE TABLE disputes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      bill_item_id UUID NOT NULL REFERENCES bill_items(id) ON DELETE CASCADE,
      raised_by_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      reason TEXT NOT NULL,
      status dispute_status NOT NULL DEFAULT 'open',
      resolved_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
      resolution_note TEXT,
      resolved_at TIMESTAMP,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );
    CREATE TABLE notification_outbox (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      event_type notification_event_type NOT NULL,
      recipient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      channel VARCHAR(32) NOT NULL DEFAULT 'line',
      payload JSONB NOT NULL,
      deduplication_key VARCHAR(255) NOT NULL UNIQUE,
      status notification_status NOT NULL DEFAULT 'PENDING',
      attempts INTEGER NOT NULL DEFAULT 0,
      max_attempts INTEGER NOT NULL DEFAULT 5,
      available_at TIMESTAMP NOT NULL DEFAULT NOW(),
      locked_at TIMESTAMP,
      sent_at TIMESTAMP,
      failed_at TIMESTAMP,
      last_error TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE INDEX notification_outbox_recipient_idx ON notification_outbox(recipient_user_id);
    CREATE INDEX notification_outbox_status_available_idx ON notification_outbox(status, available_at);

    CREATE TABLE notification_deliveries (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      notification_id UUID NOT NULL REFERENCES notification_outbox(id) ON DELETE CASCADE,
      provider VARCHAR(32) NOT NULL DEFAULT 'line',
      recipient_line_id VARCHAR(128),
      status VARCHAR(32) NOT NULL,
      attempt_number INTEGER NOT NULL,
      response_payload JSONB,
      error_message TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    CREATE INDEX notification_deliveries_notification_idx ON notification_deliveries(notification_id);
  `);

  console.log("Complete DB schema reset and recreated successfully!");
  process.exit(0);
}

main().catch((err) => {
  console.error("Migration error:", err);
  process.exit(1);
});
