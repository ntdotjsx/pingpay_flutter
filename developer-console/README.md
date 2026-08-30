# PingPay Developer & Back-Office Console (SvelteKit + TailwindCSS)

[![SvelteKit](https://img.shields.io/badge/SvelteKit-2.0+-FF3E00?logo=svelte&logoColor=white)](https://kit.svelte.dev)
[![TailwindCSS](https://img.shields.io/badge/TailwindCSS-3.4+-06B6D4?logo=tailwindcss&logoColor=white)](https://tailwindcss.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Bun](https://img.shields.io/badge/Bun-v1.3+-fbf0df?logo=bun&logoColor=black)](https://bun.sh)

> **เว็บแผงควบคุมระบบหลังบ้านสำหรับผู้ดูแลระบบและนักพัฒนา (Back-Office & Admin Console)**  
> ใช้สำหรับตรวจสอบสถิติ GMV ภาพรวม, ตรวจสอบสมุดบัญชีแยกประเภท (`financial_transactions`), ตรวจจับสลิปซ้ำและการทุจริต, จัดการข้อพิพาท, ระงับ/แบนบัญชี, และบรอดแคสต์แจ้งเตือน

---

## เอกสารที่เกี่ยวข้อง (Related Documentation)
- **[PingPay Main README](../README.md)**: ภาพรวมทั้งโปรเจกต์ โครงสร้าง Mobile App, Backend และ Web Console
- **[PingPay Backend API Reference](../elysia-api/README.md)**: สถาปัตยกรรม Backend API, โครงสร้าง 23 ตาราง และ Worker
- **[PingPay System Specification for DFD](../PINGPAY_SYSTEM_SPEC_FOR_DFD.md)**: ข้อกำหนดสถาปัตยกรรมระบบ คลังข้อมูลเชิงตรรกะ D1 - D20 และตาราง Data Balancing ครบถ้วน

---

## สารบัญ (Table of Contents)
- [บทบาทและสิทธิ์การเข้าถึง (Authorization & Roles)](#บทบาทและสิทธิ์การเข้าถึง-authorization--roles)
- [ฟังก์ชันการทำงานหลัก (Core Features)](#ฟังก์ชันการทำงานหลัก-core-features)
- [โครงสร้างโฟลเดอร์ (Project Structure)](#โครงสร้างโฟลเดอร์-project-structure)
- [การตั้งค่าตัวแปรสภาพแวดล้อม (Environment Variables)](#การตั้งค่าตัวแปรสภาพแวดล้อม-environment-variables)
- [คำสั่งการใช้งาน (Development Scripts)](#คำสั่งการใช้งาน-development-scripts)

---

## บทบาทและสิทธิ์การเข้าถึง (Authorization & Roles)

การเข้าใช้งาน Developer Console สงวนไว้สำหรับผู้ใช้ที่มีบทบาท **`role == 'developer'`** และมีสถานะบัญชี **`accountStatus == 'active'`** เท่านั้น:
- การกระทำทุกอย่างบนคอนโซล (การดูประวัติธุรกรรม, การระงับบัญชี, การตัดสินข้อพิพาท, การบรอดแคสต์) จะถูกบันทึก Audit Trail ลงตาราง `admin_action_logs` เพื่อความโปร่งใสและตรวจสอบย้อนหลังได้ 100%

---

## ฟังก์ชันการทำงานหลัก (Core Features)

### 1. แดชบอร์ดสถิติภาพรวมระบบ (GMV & System Analytics)
- สรุปยอดธุรกรรมรวมของระบบ (Gross Merchandise Volume - GMV)
- สถิติจำนวนบิลที่สร้าง, ยอดเงินที่ชำระสำเร็จ, ยอดเงินที่ยกหนี้ให้กัน
- สถิติอัตราความสำเร็จของ AI OCR และอัตราการตรวจผ่านของ EasySlip
- กราฟแนวโน้มปริมาณการใช้งานรายวันและรายเดือน

### 2. ตรวจสอบสมุดบัญชีแยกประเภทและการเงิน (Financial Ledger & Invariants)
- ตรวจสอบรายการเดินบัญชีจากตาราง `financial_transactions` แบบเรียลไทม์
- ตรวจสอบความถูกต้องของสมการความสมดุลทางการเงิน (Financial Invariant)
- ดูสแนปช็อตข้อมูล Payload ของสลิปธนาคารและผลตรวจสอบย้อนหลัง

### 3. จัดการบัญชีผู้ใช้งาน (User & Account Oversight)
- ตรวจสอบรายชื่อผู้ใช้งาน, รหัส User Code, ข้อมูลช่องทางรับเงิน, คะแนนสะสม
- ดำเนินการระงับบัญชีชั่วคราว (`suspend`) พร้อมกำหนดระยะเวลา และการแบนบัญชีถาวร (`ban`)
- บันทึกเหตุผลการระงับบัญชีลง Audit Trail โดยอัตโนมัติ

### 4. ระบบจัดการข้อพิพาททางการเงิน (Dispute Resolution Management)
- ตรวจสอบรายการข้อพิพาทที่ผู้ใช้ร้องเรียนเข้ามาเกี่ยวกับยอดหนี้หรือสลิปที่ไม่ตรงกัน
- ตรวจสอบข้อมูลบิล, รายการอาหาร/สินค้า, และภาพสลิปที่แนบมา
- ดำเนินการตัดสินข้อพิพาท (`resolved_paid`, `resolved_written_off`, `resolved_rejected`) พร้อมระบุเหตุผลประกอบ

### 5. ตรวจสอบพฤติกรรมน่าสงสัยและการทุจริต (Suspicious Activity Oversight)
- ตรวจสอบรายการแจ้งเตือนสลิปซ้ำ (Duplicate Slip Detection ผ่าน SHA-256 Hash)
- ตรวจสอบการใช้งานหลายบัญชีจาก IP หรืออุปกรณ์เดียวกัน (Multi-Account Anomaly)
- ตรวจสอบบันทึกความพยายามสุ่มรหัส PIN (PIN Brute-force Incidents)

### 6. จัดการสต็อกสินค้าของรางวัลและการจัดส่ง (Rewards Store Fulfillment)
- เพิ่ม, แก้ไข, และเปิด/ปิดการแสดงผลสินค้าของรางวัลในร้านค้า PingPay
- ตรวจสอบรายการที่ผู้ใช้แลกแต้มเข้ามา
- อัปเดตสถานะการจัดส่งพัสดุ (`pending_delivery` -> `shipped` -> `delivered`) พร้อมระบุหมายเลข Tracking Number

### 7. บรอดแคสต์ข้อความแจ้งเตือนระดับระบบ (System Broadcast Notifications)
- ส่งข้อความประกาศ/แจ้งเตือนแบบบรอดแคสต์ไปยังกลุ่มผู้ใช้เป้าหมาย
- กำหนดหัวข้อ, ข้อความ, รูปภาพแบนเนอร์, และ Deep Link
- ข้อความจะถูกนำเข้าสู่ระบบ `notification_outbox` ของ Backend เพื่อส่งผ่าน Firebase Cloud Messaging (FCM)

---

## โครงสร้างโฟลเดอร์ (Project Structure)

```
developer-console/
├── src/
│   ├── lib/                                # คอมโพเนนต์และยูทิลิตี้ส่วนกลาง
│   │   ├── api/                            # HTTP Client เชื่อมต่อกับ Backend API (Elysia.js)
│   │   ├── components/                     # UI Components (Sidebar, Navbar, Tables, Charts)
│   │   ├── stores/                         # Svelte Stores สำหรับจัดการ State และ Session
│   │   └── types/                          # TypeScript Interfaces & API Types
│   ├── routes/                             # หน้าเพจของระบบ (SvelteKit File-based Routing)
│   │   ├── (auth)/login/                   # หน้าเข้าสู่ระบบของผู้ดูแลระบบ
│   │   ├── (dashboard)/                    # หน้าแดชบอร์ดหลัก (Layout หลัก)
│   │   │   ├── users/                      # หน้ารายชื่อและจัดการผู้ใช้งาน
│   │   │   ├── transactions/               # หน้าตรวจสอบสมุดบัญชีแยกประเภท
│   │   │   ├── disputes/                   # หน้าระงับและตัดสินข้อพิพาท
│   │   │   ├── suspicious/                 # หน้าตรวจจับสลิปซ้ำและการทุจริต
│   │   │   ├── rewards/                    # หน้าจัดการของรางวัลและการจัดส่ง
│   │   │   ├── broadcast/                  # หน้าส่งแจ้งเตือนบรอดแคสต์
│   │   │   └── logs/                       # หน้าตรวจสอบ Admin Action Logs & System Audit
│   └── app.html                            # HTML Shell
├── static/                                 # ไฟล์ Static เช่น โลโก้ และ ไอคอน
├── svelte.config.js                        # การตั้งค่า SvelteKit Adapter
├── tailwind.config.ts                      # การตั้งค่า TailwindCSS
└── package.json                            # Scripts & Dependencies
```

---

## การตั้งค่าตัวแปรสภาพแวดล้อม (Environment Variables)

สร้างไฟล์ `.env` ในโฟลเดอร์ `developer-console/`:

```env
# Backend API Base URL
PUBLIC_API_URL=http://localhost:3001
```

---

## คำสั่งการใช้งาน (Development Scripts)

```bash
# ติดตั้ง Dependencies
bun install

# รันคอนโซลในโหมด Development
bun run dev

# บิลด์สำหรับ Production
bun run build

# พรีวิวผลลัพธ์ของ Production Build
bun run preview
```
> คอนโซลจะเปิดทำงานที่ `http://localhost:5173`
