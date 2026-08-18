import { sql } from "drizzle-orm";
import { db } from "./index";

async function main() {
  console.log("Applying payment tables migration...");

  await db.execute(sql`
    DO $$ BEGIN
      CREATE TYPE payment_method AS ENUM ('full', 'installment');
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;

    DO $$ BEGIN
      CREATE TYPE payment_channel AS ENUM ('promptpay_qr', 'bank_transfer', 'cash');
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;

    DO $$ BEGIN
      CREATE TYPE payment_status AS ENUM (
        'pending_verification',
        'verification_failed',
        'pending_owner_confirmation',
        'confirmed',
        'rejected',
        'cancelled',
        'refunded'
      );
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;

    DO $$ BEGIN
      ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'pending_owner_confirmation';
      ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'verification_failed';
      ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'cancelled';
      ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunded';
    EXCEPTION
      WHEN duplicate_object THEN null;
    END $$;

    CREATE TABLE IF NOT EXISTS payments (
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

    CREATE TABLE IF NOT EXISTS payment_verifications (
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
  `);

  console.log("Migration executed successfully!");
  process.exit(0);
}

main().catch((err) => {
  console.error("Migration error:", err);
  process.exit(1);
});
