# PingPay Backend API (Elysia.js + Bun + PostgreSQL)

[![Bun](https://img.shields.io/badge/Bun-v1.3+-fbf0df?logo=bun&logoColor=black)](https://bun.sh)
[![Elysia.js](https://img.shields.io/badge/Elysia.js-v1.4+-black?logo=elysia&logoColor=white)](https://elysiajs.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Drizzle ORM](https://img.shields.io/badge/Drizzle_ORM-v0.40+-C5F74F?logo=drizzle&logoColor=black)](https://orm.drizzle.team)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-Swagger_UI-85EA2D?logo=swagger&logoColor=black)](http://localhost:3001/docs)

> **เซิร์ฟเวอร์ Backend API ประสิทธิภาพสูงสำหรับระบบ PingPay**  
> ให้บริการ REST API, Realtime WebSocket Gateway, Transactional Notification Outbox Worker, และ Automated Weekly Debt Reminder Scheduler

---

## เอกสารที่เกี่ยวข้อง (Related Documentation)
- **[PingPay Main README](../README.md)**: ภาพรวมทั้งโปรเจกต์ โครงสร้าง Mobile App, Backend และ Web Console
- **[PingPay System Specification for DFD](../PINGPAY_SYSTEM_SPEC_FOR_DFD.md)**: ข้อกำหนดสถาปัตยกรรมระบบ คลังข้อมูลเชิงตรรกะ D1 - D20 และตาราง Data Balancing ครบถ้วน
- **[Developer & Back-Office Console](../developer-console/README.md)**: เว็บแผงควบคุมระบบสำหรับผู้ดูแลระบบและนักพัฒนา

---

## สารบัญ (Table of Contents)
- [สถาปัตยกรรมและการทำงาน (Architecture & Core Modules)](#สถาปัตยกรรมและการทำงาน-architecture--core-modules)
- [โครงสร้างตารางฐานข้อมูล 23 ตาราง (Database Schema)](#โครงสร้างตารางฐานข้อมูล-23-ตาราง-database-schema)
- [ระบบแจ้งเตือนและคิวงาน Outbox (Notifications & Scheduler)](#ระบบแจ้งเตือนและคิวงาน-outbox-notifications--scheduler)
- [การตั้งค่าตัวแปรสภาพแวดล้อม (Environment Variables)](#การตั้งค่าตัวแปรสภาพแวดล้อม-environment-variables)
- [คำสั่งการใช้งาน (Development Scripts)](#คำสั่งการใช้งาน-development-scripts)
- [การทดสอบระบบ (Automated Tests)](#การทดสอบระบบ-automated-tests)

---

## สถาปัตยกรรมและการทำงาน (Architecture & Core Modules)

เซิร์ฟเวอร์ถูกพัฒนาด้วย **Bun Runtime** ร่วมกับ **Elysia.js** เพื่อให้ได้ประสิทธิภาพความเร็วสูง (High Throughput & Low Latency) พร้อม TypeBox Schema Validation และ OpenAPI Swagger แบบอัตโนมัติ

```
elysia-api/src/
├── config/                                 # การโหลดและตรวจสอบ Env Variables (Type-safe)
├── db/                                     # Drizzle ORM Schema (23 Tables), Database Client
├── middleware/                             # Auth Guards, Onboarding State Machine, Rate Limiters
├── modules/                                # โมดูลฟังก์ชันทางธุรกิจ (Domain-Driven Design)
│   ├── admin/                              # Back-Office Admin Services, GMV & Audit Logs
│   ├── auth/                               # Google OAuth 2.0, PIN (Argon2id), Single Device Sessions
│   ├── bills/                              # Bill Allocation Engine, OCR Parser, NLI Processor
│   ├── friends/                            # Friendships Graph, Code Search & Nicknames
│   ├── notifications/                      # FCM v1, Debt Reminder Scheduler, Outbox Worker
│   ├── payments/                           # EasySlip QR Gen, Slip Verification, Multi-Installments
│   ├── profile/                            # Real Name Validation, Payment Channels Setup
│   └── rewards/                            # Rewards Store Catalog, Redemptions & Fulfillment
├── realtime/                               # WebSocket Server (/realtime) สำหรับ Live Updates
├── routes/                                 # Auto-loaded API Routes (Elysia Autoload)
└── index.ts                                # Entry Point และ Background Worker Lifecycle
```

---

## โครงสร้างตารางฐานข้อมูล 23 ตาราง (Database Schema)

ฐานข้อมูลใช้ **PostgreSQL 16** ควบคุมผ่าน **Drizzle ORM (`src/db/schema.ts`)** โดยแบ่งออกเป็น 23 ตารางตามขอบเขตหน้าที่:

1. `users`: บัญชีผู้ใช้, ข้อมูลส่วนตัว, ช่องทางพร้อมเพย์/ธนาคาร, คะแนนสะสม, บทบาท (`user`/`developer`), สถานะบัญชี
2. `consent_records`: ประวัติการยอมรับนโยบายคุ้มครองข้อมูลส่วนบุคคล (PDPA) ทุกเวอร์ชัน
3. `auth_identities`: ข้อมูลเชื่อมโยง Identity Provider (Google OAuth 2.0)
4. `user_credentials`: รหัสแฮช PIN 6 หลัก (Argon2id), จำนวนครั้งที่ผิด, สถานะล็อคบัญชี
5. `auth_sessions`: เซสชันอุปกรณ์เดี่ยว (Single Device Session Control), Refresh Token Hash, IP, วันหมดอายุ
6. `device_tokens`: FCM Push Notification Tokens ประจำอุปกรณ์, รุ่นมือถือ, OS Version
7. `otp_verifications`: รหัส OTP 6 หลักสำหรับรีเซ็ตรหัส PIN ทางอีเมล พร้อมอายุ 15 นาที
8. `friendships`: ความสัมพันธ์เพื่อน 2 ทิศทาง (`pending`, `accepted`, `blocked`, `rejected`)
9. `bills`: หัวบิล, ยอดเริ่มต้นถาวร (`originalTotalAmount`), ยอดรวม, ภาษี/ค่าบริการ, รูปใบเสร็จ, ผล OCR
10. `bill_items`: รายการหนี้รายบุคคล (`originalAmount`, `currentAmount`, `amountPaid`, `amountWrittenOff`, `isAcknowledged`, `isLocked`)
11. `payments`: บันทึกงวดชำระเงิน, สแนปช็อต PromptPay QR (EMVCo), ภาพสลิป, SHA-256 Hash, สถานะยืนยัน
12. `payment_verifications`: ประวัติผลการตรวจสอบสลิปจาก EasySlip API v2 พร้อม Payload การโอนจริง
13. `financial_transactions`: สมุดบัญชีแยกประเภทแบบบันทึกเพิ่มอย่างเดียว (`debt_created`, `payment`, `write_off`, `debt_adjusted`)
14. `edit_logs`: บันทึกประวัติการเปลี่ยนแปลงบิล, ยอดเงิน, การยกหนี้, และเพื่อนร่วมหาร
15. `disputes`: รายการข้อพิพาทเรื่องยอดหนี้ระหว่างสมาชิก พร้อมบันทึกการตัดสินโดย Developer/Admin
16. `notification_outbox`: คิวงานแจ้งเตือนพร้อมกลไก Deduplication Key และ Retry Exponential Backoff
17. `notification_deliveries`: ประวัติการส่งมอบแจ้งเตือนแต่ละรอบ (FCM Provider Response)
18. `admin_action_logs`: บันทึกการปฏิบัติงานของผู้ดูแลระบบ/นักพัฒนาบน Developer Console
19. `suspicious_activity_logs`: บันทึกพฤติกรรมผิดปกติ เช่น สลิปซ้ำ (Duplicate Slip), การล็อกอินผิดปกติ
20. `activity_logs`: บันทึกกิจกรรมทั่วไปของผู้ใช้ในระบบ พร้อมรอบ Purge ทุก 1 เดือน
21. `reward_items`: แคตตาล็อกของรางวัลในร้านค้า PingPay Rewards
22. `reward_redemptions`: ประวัติการแลกของรางวัล, ข้อมูลจัดส่ง, เลขพัสดุ (`trackingNumber`)
23. `security_events`: บันทึกเหตุการณ์ความปลอดภัยระดับระบบ (เช่น PIN Brute-force Detection)

---

## ระบบแจ้งเตือนและคิวงาน Outbox (Notifications & Scheduler)

- **Transactional Outbox Pattern**: ทุกการกระทำที่ต้องส่งแจ้งเตือน (สร้างบิล, สลิปเข้า, ยืนยันเงิน, ยกหนี้) จะบันทึกลง `notification_outbox` ภายใน Database Transaction เดียวกันกับข้อมูลหลัก
- **Background Worker (`NotificationWorkerService`)**: โพลคิวงานที่ถึงกำหนดส่ง (`availableAt <= NOW()`) ด้วยคำสั่ง `FOR UPDATE SKIP LOCKED` เพื่อรองรับการสเกลแบบ Multi-Instance
- **Exponential Backoff**: หากการส่งผ่าน FCM ขัดข้อง ระบบจะหน่วงเวลาลองใหม่ตามลำดับ: 10 วินาที, 1 นาที, 5 นาที, 15 นาที, 30 นาที
- **Automated Weekly Debt Reminders (8.9.1)**:
  - ประมวลผลหนี้ที่ยังค้างชำระ (`currentAmount - amountPaid - amountWrittenOff > 0`)
  - คำนวณ ISO Week Key (เช่น `2026-W35`) ตามเขตเวลา `Asia/Bangkok`
  - ป้องกันการส่งซ้ำในสัปดาห์เดียวกันด้วยคีย์ `DEBT_WEEKLY_REMINDER:{billItemId}:{weekKey}`

---

## การตั้งค่าตัวแปรสภาพแวดล้อม (Environment Variables)

สร้างไฟล์ `.env` ในโฟลเดอร์ `elysia-api/` โดยอ้างอิงจากตัวอย่าง:

```env
# Server
PORT=3001
NODE_ENV=development

# Database
DATABASE_URL=postgres://postgres:password@localhost:5432/pingpay_db

# Security & Tokens
JWT_ACCESS_SECRET=your-jwt-access-secret-key-here
JWT_REFRESH_SECRET=your-jwt-refresh-secret-key-here
ARGON2_SECRET=your-argon2-pepper-key-here

# EasySlip Service (PromptPay QR & Slip Verification)
EASYSLIP_API_KEY=your-easyslip-api-key
EASYSLIP_BASE_URL=https://api.easyslip.com

# AI OCR Service
OCR_SERVICE_URL=http://localhost:8000/api/v1/ocr

# Firebase Cloud Messaging (FCM HTTP v1)
GOOGLE_APPLICATION_CREDENTIALS=./pingpay-firebase-adminsdk.json

# Email / SMTP (Forgot PIN OTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

---

## คำสั่งการใช้งาน (Development Scripts)

```bash
# ติดตั้ง Dependencies
bun install

# รันเซิร์ฟเวอร์ในโหมด Development (พร้อม Hot Reload)
bun dev

# ซิงค์ Schema กับฐานข้อมูล PostgreSQL
bun run db:push

# เปิด Drizzle Studio สำหรับดูข้อมูลผ่านเว็บ
bun run db:studio

# รัน Migration
bun run db:migrate
```

---

## การทดสอบระบบ (Automated Tests)

```bash
# รัน Unit Tests ทั้งหมด
bun test tests/unit/

# รันเฉพาะการทดสอบระบบแจ้งเตือนและ Weekly Scheduler
bun test tests/unit/notifications/

# รัน Integration Tests
bun test tests/integration/
```