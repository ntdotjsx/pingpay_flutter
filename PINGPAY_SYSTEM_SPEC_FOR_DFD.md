# PingPay — ข้อมูลระบบและคู่มือข้อกำหนดสำหรับออกแบบ DFD (Data Flow Diagram)
> **เอกสารอ้างอิงฉบับสมบูรณ์ (System Specification & DFD Reference Manual)**  
> รวบรวมข้อมูลตามสถาปัตยกรรมจริงของโปรเจกต์จากทั้ง 3 องค์ประกอบ: **Flutter Mobile App (`lib/`)**, **Elysia Backend API (`elysia-api/`)**, และ **Developer / Back-Office Console (`developer-console/`)**

---

## 📌 กติกาและมาตรฐานการเขียน DFD สำหรับระบบนี้
1. **Context Diagram (Level 0)**:
   - มีเพียง **Process 0.0: ระบบจัดการค่าใช้จ่ายร่วมกันและการชำระเงินผ่านพร้อมเพย์ (PingPay System)** เพียง Process เดียว
   - **ไม่มี Data Store** ใน Context Diagram
   - มี **External Entities (E1 - E7)** ทั้งหมดที่สื่อสารกับระบบ โดยมีทิศทาง Data Flow เข้า-ออกอย่างชัดเจน
   - Data Flow ทุกเส้นต้องระบุเป็น **"กลุ่มข้อมูล (Concrete Noun Phrase)"** เช่น *"ข้อมูลการสร้างบิล"*, *"ผลการตรวจสอบสลิป"* (ห้ามใช้คำกว้าง ๆ หรือคำกริยา เช่น *"จัดการข้อมูล"*, *"บันทึกข้อมูล"*)
2. **Level 1 DFD**:
   - ใช้หมายเลขกำกับเป็น **1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0**
   - มี **Logical Data Stores (D1 - D10)** เชื่อมต่อข้อมูลระหว่าง Process
   - **Data Balancing**: Data Flow ที่เข้า-ออกจาก External Entity ใน Level 1 ต้องตรงกัน 100% กับใน Context Diagram (ชื่อและทิศทางข้อมูลตรงกัน)
3. **Level 2 DFD**:
   - แตก Process ย่อยเป็น **1.1, 1.2..., 2.1, 2.2...** จนถึงระดับฟังก์ชันปฏิบัติการ
   - รักษา Data Balancing จาก Level 1 อย่างเคร่งครัด
4. **Logical Data Store**:
   - **ไม่สร้าง Data Store ตามทุก Table ของฐานข้อมูลแบบ 1:1 (ไม่มองเป็น ER Diagram)**
   - รวมกลุ่มข้อมูลเชิงตรรกะตามขอบเขตหน้าที่ (Domain Responsibility)
5. **การตั้งชื่อ Data Flow**:
   - ระบุชนิดข้อมูลที่ไหลจริง เช่น *"รหัส OTP ยืนยัน"*, *"ภาพถ่ายใบเสร็จ"*, *"ยอดเงินที่ต้องการชำระ"*, *"ประวัติการแลกของรางวัล"*

---

## 1. External Entities (เอนทิตีภายนอก 7 ตัว)

```
+-----------------------------------------------------------------------------------+
|                              EXTERNAL ENTITIES (7 ตัว)                            |
+-----------------------------------------------------------------------------------+
| E1: ผู้ใช้งานทั่วไป (End User: เจ้าของบิล Creditor / ผู้ร่วมหาร Debtor)           |
| E2: ผู้ดูแลระบบและผู้พัฒนา (Developer / Admin - ใช้งานผ่าน Developer Console)    |
| E3: ระบบ Google Identity (Google Sign-In OAuth 2.0 Service)                       |
| E4: ระบบ EasySlip Service (EasySlip API v1 QR Generator & v2 Verification)       |
| E5: ระบบ AI OCR Service (Receipt AI OCR Engine - FastAPI + PaddleOCR/EasyOCR)     |
| E6: ระบบ Firebase Cloud Messaging (FCM HTTP v1 Push Notification Service)        |
| E7: ระบบส่งอีเมล (Email / SMTP Service สำหรับ OTP Reset PIN)                     |
+-----------------------------------------------------------------------------------+
```

| รหัส | ชื่อ Entity | หน้าที่และขอบเขตการทำงาน |
| :--- | :--- | :--- |
| **E1** | **ผู้ใช้งานทั่วไป (End User)** | ผู้ใช้แอปมือถือ (ทั้งผู้สร้างบิล/เจ้าหนี้ และผู้ร่วมหาร/ลูกหนี้) ทำธุรกรรมหารเงิน, ป้อนข้อความสร้างบิล (NLI), สแกนใบเสร็จ, ตอบรับหนี้, ชำระเงินผ่าน PromptPay, แนบสลิป, ยกหนี้, แลกของรางวัล |
| **E2** | **ผู้ดูแลระบบและผู้พัฒนา (Developer / Admin)** | ผู้ดูแลระบบที่ใช้งานผ่าน **Developer Console** (Web) เพื่อดูสถิติ GMV, ตรวจสอบธุรกรรมการเงิน, ระงับ/แบนบัญชี, จัดการข้อพิพาท, จัดการสต็อกของรางวัล, บรอดแคสต์แจ้งเตือน |
| **E3** | **ระบบ Google Identity** | ผู้ให้บริการภายนอกสำหรับยืนยันตัวตน Google OAuth 2.0 และส่งคืน Google Profile (Google ID, Email, Name, Picture) |
| **E4** | **ระบบ EasySlip Service** | บริการภายนอกสำหรับ:<br>1. **API v1**: สร้าง Dynamic PromptPay QR / TrueMoney QR พร้อมระบุยอดเงินตรงบิล<br>2. **API v2**: ตรวจสอบสลิปโอนเงินธนาคารแบบเรียลไทม์ (ชื่อ-เลขบัญชีผู้รับ, ยอดเงิน, วันเวลา, Ref No.) |
| **E5** | **ระบบ AI OCR Service** | บริการประมวลผลภาพถ่ายใบเสร็จ (FastAPI + PaddleOCR/EasyOCR) สกัดรายการสินค้า, จำนวน, ราคาแต่ละชิ้น, ภาษี/ค่าบริการ และยอดรวม |
| **E6** | **ระบบ Firebase Cloud Messaging (FCM)** | บริการส่ง Push Notification ไปยังสมาร์ตโฟนของผู้ใช้ (แจ้งเตือนบิลใหม่, ทวงหนี้, สลิปเข้า, ผลยืนยัน, แจ้งเตือนยอดค้างชำระรายสัปดาห์ 8.9.1) |
| **E7** | **ระบบส่งอีเมล (Email / SMTP Service)** | บริการส่งรหัส OTP 6 หลักทางอีเมลสำหรับการรีเซ็ตรหัส PIN เมื่อผู้ใช้ลืมรหัส |

---

## 2. Logical Data Stores (คลังข้อมูลเชิงตรรกะ 10 กลุ่ม)

```
+--------------------------------------------------------------------------------------+
|                               LOGICAL DATA STORES (10 กลุ่ม)                         |
+--------------------------------------------------------------------------------------+
| D1: ข้อมูลบัญชีผู้ใช้และการเข้าสู่ระบบ (User Accounts & Auth Identities Store)        |
| D2: ข้อมูลความปลอดภัยและเซสชัน (Security, Credentials & Device Sessions Store)        |
| D3: ข้อมูลช่องทางการรับเงิน (Payment Channels Store)                                 |
| D4: ข้อมูลเพื่อนและความสัมพันธ์ (Friendships & Nicknames Store)                       |
| D5: ข้อมูลบิลและการหารค่าใช้จ่าย (Bills & Splitting Items Store)                      |
| D6: ข้อมูลภาระหนี้และการชำระเงิน (Debts & Payment Transactions Store)                 |
| D7: ข้อมูลสลิปและการตรวจสอบ (Slips & Verification Audit Logs Store)                  |
| D8: ข้อมูลการแจ้งเตือนและคิวงาน (Notifications Outbox & Schedules Store)             |
| D9: ข้อมูลร้านค้าและประวัติการแลกของรางวัล (Rewards Catalog & Redemptions Store)      |
| D10: ข้อมูลการตรวจสอบและข้อพิพาทหลังบ้าน (Admin Audit Logs & Disputes Store)         |
+--------------------------------------------------------------------------------------+
```

| รหัส | ชื่อ Logical Data Store | รายละเอียดโครงสร้างข้อมูลที่จัดเก็บ | แหล่งข้อมูลในฐานข้อมูลจริง (DB Tables Mapping) |
| :--- | :--- | :--- | :--- |
| **D1** | **ข้อมูลบัญชีผู้ใช้และการเข้าสู่ระบบ** | ข้อมูลโปรไฟล์ผู้ใช้ (User Code, Display Name, ชื่อ-นามสกุลจริงภาษาไทย/อังกฤษ, ที่อยู่, เบอร์โทร), สถานะ Onboarding, ข้อมูลเชื่อมโยง Google Provider (Google ID, Email), บันทึกประวัติการยอมรับ PDPA แต่ละเวอร์ชัน, บทบาท (User/Developer), สถานะบัญชี (Active/Suspended/Banned) | `users`, `auth_identities`, `consent_records` |
| **D2** | **ข้อมูลความปลอดภัยและเซสชัน** | รหัสแฮช PIN (Argon2id/Bcrypt), จำนวนครั้งที่กรอกผิด, สถานะล็อคบัญชี, ข้อมูล Active Device Session (Device UUID, Refresh Token Hash, IP, วันหมดอายุ), รหัสแฮช OTP รีเซ็ต PIN, บันทึกเหตุการณ์ความปลอดภัย (Security Events) | `user_credentials`, `auth_sessions`, `otp_verifications`, `security_events` |
| **D3** | **ข้อมูลช่องทางการรับเงิน** | หมายเลขพร้อมเพย์ (PromptPay ID & Type: เบอร์มือถือ/เลขบัตรประชาชน), เบอร์ TrueMoney Wallet, ข้อมูลบัญชีธนาคาร (Bank Code, Account No.), สถานะการยืนยันช่องทางรับเงินผ่านสลิปจริง (`promptPayVerifiedAt`) | `users` (Payment Channel Columns) |
| **D4** | **ข้อมูลเพื่อนและความสัมพันธ์** | ความสัมพันธ์เพื่อนแบบ 2 ทิศทาง (Requester ID, Addressee ID, Status: Pending/Accepted/Blocked), QR Code ข้อมูลเพื่อน, ชื่อเล่นเฉพาะบุคคลที่ผู้ใช้ตั้งให้เพื่อน (Custom Nicknames) | `friendships`, Custom Nickname Storage |
| **D5** | **ข้อมูลบิลและการหารค่าใช้จ่าย** | ข้อมูลบิล (Title, Note, Total Amount), **ยอดเริ่มต้นถาวร (`originalTotalAmount`)**, สัดส่วนของเจ้าของบิล (`myShare`), ข้อมูลรายการอาหาร/สินค้า (Items Breakdown: Subtotal, Service Charge, Tax), ภาพถ่ายใบเสร็จ, ประวัติการแก้ไขบิล (`edit_logs`) | `bills`, `edit_logs` |
| **D6** | **ข้อมูลภาระหนี้และการชำระเงิน** | รายการหนี้รายบุคคล (`bill_items`: originalAmount, currentAmount, amountPaid, amountWrittenOff, isAcknowledged, isLocked), บันทึกงวดการชำระเงิน (`payments`: installmentNumber, method, channel, status), บัญชีแยกประเภทธุรกรรมการเงิน (`financial_transactions`: debt_created, payment, write_off, debt_adjusted) | `bill_items`, `payments`, `financial_transactions` |
| **D7** | **ข้อมูลสลิปและการตรวจสอบ** | ภาพสลิปโอนเงิน, SHA-256 Hash ของไฟล์สลิป (ป้องกันสลิปซ้ำ), ผลการตรวจสอบสลิปจาก EasySlip (`payment_verifications`: ผู้โอน-ผู้รับ, ยอดจริง, วันเวลา, Ref No., Raw Response, Failure Code) | `payments` (Slip columns), `payment_verifications` |
| **D8** | **ข้อมูลการแจ้งเตือนและคิวงาน** | คิวข้อความแจ้งเตือน Outbox (`notification_outbox`: eventType, payload, deduplicationKey, retry attempts, status), ประวัติการส่งมอบ (`notification_deliveries`), FCM Device Tokens ของอุปกรณ์, กำหนดการแจ้งเตือนหนี้ประจำสัปดาห์ (Weekly Reminders) | `notification_outbox`, `notification_deliveries`, `device_tokens` |
| **D9** | **ข้อมูลร้านค้าและประวัติการแลกของรางวัล** | แคตตาล็อกของรางวัล (`reward_items`: title, description, pointsCost, category, stock, isActive), ยอดคะแนนสะสม PingPay Coins ของผู้ใช้ (`rewardPoints`), ประวัติการแลกของรางวัล (`reward_redemptions`: shippingAddress, trackingNumber, status) | `reward_items`, `reward_redemptions`, `users.reward_points` |
| **D10** | **ข้อมูลการตรวจสอบและข้อพิพาทหลังบ้าน** | รายการข้อพิพาทระหว่างผู้ใช้ (`disputes`: reason, status, resolutionNote, resolvedById), บันทึกพฤติกรรมน่าสงสัย (`suspicious_activity_logs`: duplicate slips, anomaly logs), บันทึกการกระทำของผู้ดูแลระบบ (`admin_action_logs`: adminId, actionType, targetUserId, metadata), บันทึกกิจกรรมทั่วไป (`activity_logs`) | `disputes`, `suspicious_activity_logs`, `admin_action_logs`, `activity_logs` |

---

## 3. ผังกระบวนการทำงานหลัก (Level 1 Processes 1.0 - 7.0)

```mermaid
graph TD
    subgraph "Level 1 DFD: PingPay System Architecture"
        P1["1.0 จัดการการยืนยันตัวตนและความปลอดภัย<br>(User Authentication & Security Management)"]
        P2["2.0 จัดการโปรไฟล์ ช่องทางการเงิน และเพื่อน<br>(Profile, Payment Channels & Friends Management)"]
        P3["3.0 จัดการการสร้างบิลและหารค่าใช้จ่าย<br>(Bill Creation, OCR, NLI & Splitting Management)"]
        P4["4.0 ดำเนินการชำระเงิน ตรวจสอบสลิป และยกหนี้<br>(Payment Processing, Slip Verification & Write-off)"]
        P5["5.0 สรุปรายงาน ไทม์ไลน์ และระบบแจ้งเตือน<br>(Financial Analytics, Timeline & Notifications)"]
        P6["6.0 จัดการร้านค้าและแลกของรางวัล<br>(Rewards Store & Points Redemption)"]
        P7["7.0 จัดการระบบและตรวจสอบความปลอดภัยหลังบ้าน<br>(Back-Office Administration & Developer Console)"]
    end
```

---

## 4. รายละเอียดกระบวนการย่อย (Level 2 Processes Breakdown)

### 🔴 Process 1.0: จัดการการยืนยันตัวตนและความปลอดภัยของผู้ใช้ (Authentication & Security)

```
Process 1.0 Sub-processes:
├── 1.1 ตรวจสอบสิทธิ์และเข้าสู่ระบบผ่าน Google OAuth 2.0 (Google Sign-In)
├── 1.2 ตรวจสอบและบันทึกความยินยอม PDPA Consent
├── 1.3 ตั้งค่าและตรวจสอบรหัส PIN 6 หลัก (PIN Setup & Verification)
├── 1.4 ควบคุมเซสชันอุปกรณ์เดียว (Single Active Device Session Control)
├── 1.5 ขอและตรวจสอบรหัส OTP สำหรับรีเซ็ต PIN (Forgot PIN Reset via Email OTP)
└── 1.6 ตรวจสอบสิทธิ์และบทบาทผู้ดูแลระบบ (Admin Role Authorization)
```

- **1.1 ตรวจสอบสิทธิ์ผ่าน Google OAuth 2.0**:
  - **Input**: *ข้อมูลการขอเข้าสู่ระบบ (Google ID Token / Auth Code)* จาก ผู้ใช้งาน (E1)
  - **External Communication**: ส่ง *คำขอตรวจสอบ Token* ไปยัง Google Identity (E3) และรับ *ข้อมูลโปรไฟล์ที่ยืนยันแล้ว (Google ID, Email, Name, Picture)* กลับมา
  - **Data Store**: บันทึก/ค้นหาข้อมูลบัญชีผู้ใช้ใน **D1 (User Accounts)**
  - **Output**: *สถานะการเข้าสู่ระบบและขั้นตอน Onboarding (PDPA_REQUIRED -> PROFILE_REQUIRED -> PIN_REQUIRED -> COMPLETED)* ส่งกลับให้ ผู้ใช้งาน (E1)
- **1.2 ตรวจสอบและบันทึกความยินยอม PDPA Consent**:
  - **Input**: *ข้อมูลการยอมรับนโยบาย PDPA (Policy Version, Acceptance)* จาก ผู้ใช้งาน (E1)
  - **Data Store**: บันทึกประวัติการยินยอมลง **D1 (User Accounts)**
  - **Output**: *ผลการบันทึกความยินยอม PDPA* ส่งกลับให้ ผู้ใช้งาน (E1)
- **1.3 ตั้งค่าและตรวจสอบรหัส PIN 6 หลัก**:
  - **Input**: *รหัส PIN 6 หลัก* จาก ผู้ใช้งาน (E1)
  - **Data Store**: แฮชรหัสผ่านด้วย Argon2id/Bcrypt และบันทึก/ตรวจสอบใน **D2 (Security & Credentials)**; หากกรอกผิดเกิน 5 ครั้งจะบันทึกสถานะล็อคบัญชีชั่วคราว
  - **Output**: *ผลการตรวจสอบรหัส PIN / สถานะการล็อค* ส่งกลับให้ ผู้ใช้งาน (E1)
- **1.4 ควบคุมเซสชันอุปกรณ์เดียว (Single Active Device Session)**:
  - **Input**: *ข้อมูลระบุตัวตนอุปกรณ์ (Device UUID, Device Info, FCM Token)* จาก ผู้ใช้งาน (E1)
  - **Data Store**: ตรวจสอบและบันทึก Refresh Token Hash ใน **D2 (Security & Credentials)**; หากมีการเข้าสู่ระบบจากเครื่องใหม่ อุปกรณ์เดิมจะถูกยกเลิกเซสชันทันที (`SESSION_TERMINATED`)
  - **Output**: *JWT Access Token และ Refresh Token ประจำอุปกรณ์* ส่งกลับให้ ผู้ใช้งาน (E1)
- **1.5 ขอและตรวจสอบรหัส OTP สำหรับรีเซ็ต PIN**:
  - **Input**: *คำขอรีเซ็ต PIN (อีเมล)* จาก ผู้ใช้งาน (E1)
  - **External Communication**: สร้างรหัส OTP 6 หลัก แฮชบันทึกลง **D2** และส่ง *รหัส OTP ยืนยันตัวตน* ไปยัง ระบบส่งอีเมล (E7)
  - **Verification**: รับ *รหัส OTP ที่กรอกยืนยัน* จาก ผู้ใช้งาน (E1) ตรวจสอบกับ **D2** เพื่ออนุญาตให้ตั้งรหัส PIN ใหม่
  - **Output**: *ผลการยืนยัน OTP และสิทธิ์การตั้ง PIN ใหม่* ส่งกลับให้ ผู้ใช้งาน (E1)
- **1.6 ตรวจสอบสิทธิ์ผู้ดูแลระบบ (Admin Role Authorization)**:
  - **Input**: *ข้อมูลเข้าสู่ระบบของผู้ดูแลระบบ* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: ตรวจสอบบทบาท `role == 'developer'` และสถานะ `accountStatus == 'active'` ใน **D1 (User Accounts)**
  - **Output**: *สิทธิ์การเข้าใช้งาน Developer Console* ส่งกลับให้ ผู้ดูแลระบบ (E2)

---

### 🟠 Process 2.0: จัดการโปรไฟล์ ช่องทางการเงิน และรายชื่อเพื่อน (Profile, Payment Channels & Friends)

```
Process 2.0 Sub-processes:
├── 2.1 ตรวจสอบและบันทึกชื่อ-นามสกุลจริง (Real Name Validation)
├── 2.2 ตั้งค่าและผูกช่องทางการรับเงิน (PromptPay, TrueMoney, Thai Bank Accounts)
├── 2.3 จัดการความสัมพันธ์เพื่อน (Add Friend by Code, QR Scanner, Accept Request)
└── 2.4 ตั้งชื่อเล่นและดูสรุปความสัมพันธ์เพื่อน (Custom Nicknames & Debt Leaderboard)
```

- **2.1 ตรวจสอบและบันทึกชื่อ-นามสกุลจริง**:
  - **Input**: *ข้อมูลชื่อ-นามสกุลจริงภาษาไทย/อังกฤษ* จาก ผู้ใช้งาน (E1)
  - **Logic**: ตรวจสอบว่าต้องมีทั้งชื่อและนามสกุล ไม่มีตัวเลขหรืออักขระพิเศษ
  - **Data Store**: บันทึกลง **D1 (User Accounts)** เพื่อใช้ตรวจสอบเทียบกับชื่อบัญชีผู้รับเงินในสลิป
  - **Output**: *ผลการตรวจสอบและบันทึกชื่อ-นามสกุล* ส่งกลับให้ ผู้ใช้งาน (E1)
- **2.2 ตั้งค่าและผูกช่องทางการรับเงิน**:
  - **Input**: *ข้อมูลช่องทางรับเงิน (PromptPay ID & Type, TrueMoney No., Bank Code & Account No.)* จาก ผู้ใช้งาน (E1)
  - **Data Store**: บันทึกลง **D3 (Payment Channels)**
  - **Output**: *สถานะการผูกช่องทางรับเงิน* ส่งกลับให้ ผู้ใช้งาน (E1)
- **2.3 จัดการความสัมพันธ์เพื่อน**:
  - **Input**: *คำขอเพิ่มเพื่อน (User Code / สแกน QR Code)* จาก ผู้ใช้งาน (E1)
  - **Data Store**: บันทึกคำขอและสถานะเพื่อน (Pending -> Accepted) ลง **D4 (Friendships & Nicknames)**
  - **Notification**: ส่ง Event แจ้งเตือนเพื่อนใหม่ไปยัง **D8 (Notifications Outbox)** เพื่อยิง Push Notification
  - **Output**: *รายชื่อและข้อมูลโปรไฟล์เพื่อน* ส่งกลับให้ ผู้ใช้งาน (E1)
- **2.4 ตั้งชื่อเล่นและดูสรุปความสัมพันธ์เพื่อน**:
  - **Input**: *ข้อมูลชื่อเล่นที่กำหนดให้เพื่อน (Custom Nickname)* จาก ผู้ใช้งาน (E1)
  - **Data Store**: บันทึกชื่อเล่นลง **D4 (Friendships & Nicknames)** และดึงประวัติภาระหนี้จาก **D6 (Debts)** มาประมวลผลเป็นอันดับเพื่อน/ยอดค้าง
  - **Output**: *หน้ารายละเอียดเพื่อน, ชื่อเล่นที่แสดงผล, สรุปยอดหนี้ระหว่างกัน* ส่งกลับให้ ผู้ใช้งาน (E1)

---

### 🟡 Process 3.0: จัดการการสร้างบิลและหารค่าใช้จ่าย (Bill Creation, OCR, NLI & Splitting)

```
Process 3.0 Sub-processes:
├── 3.1 สกัดรายการและราคาจากใบเสร็จด้วย AI OCR (Receipt OCR Processing)
├── 3.2 สร้างบิลด้วยภาษาธรรมชาติ (Natural Language Bill Creation - NLI)
├── 3.3 สร้างบิลและจัดสรรยอดหนี้ตามสัดส่วน (Bill Creation & Debt Allocation Engine)
├── 3.4 แก้ไขบิลภายใต้เงื่อนไขเพดานยอดเงิน (Bill Modification & Ceiling Guard)
└── 3.5 ยกเลิกบิลภายใต้เงื่อนไขล็อคการชำระเงิน (Bill Cancellation & Payment Lock Policy)
```

- **3.1 สกัดรายการและราคาจากใบเสร็จด้วย AI OCR**:
  - **Input**: *ภาพถ่ายใบเสร็จรับเงิน* จาก ผู้ใช้งาน (E1)
  - **External Communication**: ส่ง *คำขอสกัดข้อความใบเสร็จ* ไปยัง AI OCR Service (E5) และรับ *รายการสินค้า, ราคาแต่ละชิ้น, ภาษี/ค่าบริการ, ยอดรวม* กลับมา
  - **Output**: *รายการสินค้าและราคาที่สกัดได้จากใบเสร็จ* แสดงบนหน้าจอเพื่อให้ ผู้ใช้งาน (E1) ตรวจสอบและแก้ไข
- **3.2 สร้างบิลด้วยภาษาธรรมชาติ (NLI Input)**:
  - **Input**: *ข้อความภาษาธรรมชาติ (เช่น "กินชาบู 4 คน คนละ 250 รวม 1000")* จาก ผู้ใช้งาน (E1)
  - **Logic**: วิเคราะห์โครงสร้างข้อความเพื่อดึงชื่อรายการ, ยอดรวม, จำนวนคน, และยอดเฉลี่ยรายคน
  - **Output**: *พรีวิวบิลและรายชื่อผู้ร่วมหารที่ถูกจัดสรรโดยอัตโนมัติ* แสดงให้ ผู้ใช้งาน (E1) ยืนยัน
- **3.3 สร้างบิลและจัดสรรยอดหนี้ตามสัดส่วน**:
  - **Input**: *ข้อมูลบิลและรายชื่อผู้ร่วมหาร (Title, Total Amount, Participants, Selected Items)* จาก ผู้ใช้งาน (E1)
  - **Business Logic**:
    - คำนวณส่วนของเจ้าของบิล (`myShare`) และยอดของเพื่อนแต่ละคน
    - บันทึกยอดเริ่มต้นถาวร `originalTotalAmount` และ `originalAmount` ประจำตัวเพื่อนแต่ละคน
  - **Data Store**: บันทึกหัวบิลลง **D5 (Bills)** และสร้างรายการหนี้รายบุคคลลง **D6 (Debts)**
  - **Notification**: ส่ง Event สร้างบิลไปยัง **D8 (Notifications Outbox)** เพื่อส่ง Push Notification
  - **Output**: *ผลการสร้างบิลและสรุปยอดจัดสรรหนี้* ส่งกลับให้ ผู้ใช้งาน (E1)
- **3.4 แก้ไขบิลภายใต้เงื่อนไขเพดานยอดเงิน**:
  - **Input**: *ข้อมูลการแก้ไขบิล/ปรับยอดเพื่อน* จาก ผู้ใช้งาน (E1)
  - **Security Guard**:
    - ตรวจสอบ `hasAnyPayment`: หากมีรายการชำระเงินเข้ามาแล้ว (`amountPaid > 0`) **จะไม่อนุญาตให้แก้ไข**
    - ตรวจสอบเพดานยอดเงิน: $\text{Current Amount} \le \text{Original Total Amount}$ (ห้ามปรับยอดสูงกว่ายอดสร้างแรกเริ่ม)
  - **Data Store**: อัปเดตข้อมูลใน **D5 (Bills)**, **D6 (Debts)** และบันทึกประวัติลง `edit_logs` ใน **D5**
  - **Output**: *ผลการแก้ไขบิล / แจ้งเตือนข้อผิดพลาด* ส่งกลับให้ ผู้ใช้งาน (E1)
- **3.5 ยกเลิกบิลภายใต้เงื่อนไขล็อคการชำระเงิน**:
  - **Input**: *คำขอยกเลิกบิลและเหตุผล* จาก ผู้ใช้งาน (E1)
  - **Security Guard**: ตรวจสอบว่าบิลยังไม่มีการชำระเงิน หากมี `amountPaid > 0` จะปฏิเสธคำขอยกเลิกทันที (`PAID_DEBT_LOCKED`)
  - **Data Store**: อัปเดตสถานะบิลเป็น `cancelled` ใน **D5 (Bills)** และยกเลิกภาระหนี้ทั้งหมดใน **D6 (Debts)**
  - **Output**: *ผลการยกเลิกบิล* ส่งกลับให้ ผู้ใช้งาน (E1)

---

### 🟢 Process 4.0: ดำเนินการชำระเงิน ตรวจสอบสลิป และยกหนี้ (Payments, Verification & Write-off)

```
Process 4.0 Sub-processes:
├── 4.1 ตอบรับและยอมรับภาระหนี้ (Debt Acknowledgement Swipe)
├── 4.2 สร้าง Dynamic QR Code สำหรับชำระเงิน (EasySlip Dynamic QR Generation)
├── 4.3 อัปโหลดสลิปและตรวจสอบความถูกต้องอัตโนมัติ (EasySlip Verification & Dedup)
├── 4.4 เจ้าของบิลยืนยันหรือปฏิเสธยอดเงิน (Owner Confirmation / Rejection)
├── 4.5 จัดการการชำระเงินแบบหลายงวด (Partial Payment & Installment Tracking)
└── 4.6 ดำเนินการยกหนี้ให้เพื่อน (Debt Write-off Management)
```

- **4.1 ตอบรับและยอมรับภาระหนี้**:
  - **Input**: *คำขอยืนยันยอมรับหนี้* จาก ผู้ใช้งาน (E1 - ลูกหนี้)
  - **Data Store**: อัปเดตสถานะ `isAcknowledged = true` ใน **D6 (Debts)**
  - **Output**: *สถานะหนี้ที่ยอมรับแล้วพร้อมปุ่มชำระเงิน* ส่งกลับให้ ผู้ใช้งาน (E1)
- **4.2 สร้าง Dynamic QR Code สำหรับชำระเงิน**:
  - **Input**: *คำขอสร้าง QR และยอดเงินที่ต้องการชำระ (เต็มจำนวน / บางส่วน)* จาก ผู้ใช้งาน (E1)
  - **Data Store**: ดึง PromptPay ID / TrueMoney No. ของเจ้าหนี้จาก **D3 (Payment Channels)**
  - **External Communication**: ส่งข้อมูลไปยัง EasySlip Service (E4) เพื่อรับ *ภาพและ Payload ของ Dynamic QR Code*
  - **Output**: *ภาพ QR Code ชำระเงินตรงยอด* แสดงบนหน้าจอ ผู้ใช้งาน (E1)
- **4.3 อัปโหลดสลิปและตรวจสอบความถูกต้องอัตโนมัติ**:
  - **Input**: *ภาพสลิปโอนเงินธนาคาร* จาก ผู้ใช้งาน (E1)
  - **Anti-Fraud & Hash Check**: คำนวณ SHA-256 Hash ของสลิป ตรวจสอบกับ **D7 (Slips & Verifications)** หากพบสลิปซ้ำจะบันทึกลง **D10 (Suspicious Activity Logs)** และปฏิเสธทันที
  - **External Verification**: ส่งภาพสลิปให้ EasySlip Service (E4) ตรวจสอบความถูกต้อง (ยอดเงิน, วันเวลา, ชื่อ-เลขบัญชีผู้รับ)
  - **Data Store**: บันทึกงวดชำระเงินสถานะ `pending_owner_confirmation` ลง **D6 (Debts)** และบันทึกผลตรวจสอบลง **D7 (Slips & Verifications)**
  - **Output**: *ผลการตรวจสอบสลิปเบื้องต้น* ส่งกลับให้ ผู้ใช้งาน (E1)
- **4.4 เจ้าของบิลยืนยันหรือปฏิเสธยอดเงิน**:
  - **Input**: *คำสั่งยืนยันรับเงิน หรือ ปฏิเสธสลิปพร้อมเหตุผล* จาก ผู้ใช้งาน (E1 - เจ้าหนี้)
  - **Data Store**:
    - กรณียืนยัน: อัปเดตสถานะการชำระเงินเป็น `confirmed`, เพิ่มยอด `amountPaid`, ลดหนี้คงค้างใน **D6 (Debts)** และบันทึกลงบัญชีแยกประเภท `financial_transactions`
    - กรณีปฏิเสธ: อัปเดตสถานะเป็น `rejected` หนี้คงค้างไม่เปลี่ยนแปลง
  - **Notification**: ส่งข้อความแจ้งเตือนผลไปยัง **D8 (Notifications Outbox)**
  - **Output**: *ผลการยืนยัน/ปฏิเสธยอดเงิน* ส่งกลับให้ ผู้ใช้งาน (E1)
- **4.5 จัดการการชำระเงินแบบหลายงวด**:
  - **Logic**: รักษาประวัติแยกแต่ละงวด (`installmentNumber: 1, 2, 3...`) ใน **D6 (Debts)** โดยไม่บันทึกทับยอดเดิม
  - **Output**: *ประวัติการชำระเงินรายงวด* แสดงในหน้ารายละเอียดการชำระเงิน
- **4.6 ดำเนินการยกหนี้ให้เพื่อน**:
  - **Input**: *คำขอยกหนี้ (จำนวนเงิน, เหตุผล)* จาก ผู้ใช้งาน (E1 - เจ้าของบิล)
  - **Data Store**: เพิ่มยอด `amountWrittenOff`, ลดหนี้คงค้างใน **D6 (Debts)**, บันทึกการยกหนี้ลง `edit_logs` ใน **D5** และบันทึกบัญชีแยกประเภทใน **D6**
  - **Output**: *สถานะการยกหนี้และยอดหนี้คงเหลือใหม่* ส่งกลับให้ ผู้ใช้งาน (E1)

---

### 🔵 Process 5.0: สรุปรายงาน ไทม์ไลน์ และระบบแจ้งเตือน (Analytics, Timeline & Notifications)

```
Process 5.0 Sub-processes:
├── 5.1 ประมวลผลและสรุปยอดสถิติแดชบอร์ดและรายปี (Dashboard, Monthly & Yearly Analytics)
├── 5.2 แสดงไทม์ไลน์และปฏิทินการเงิน (Daily Financial Timeline & Calendar View)
├── 5.3 ส่งการแจ้งเตือนแบบเรียลไทม์และ Push Notification (FCM Push & In-App Realtime)
└── 5.4 ประมวลผลรอบเตือนหนี้ประจำสัปดาห์อัตโนมัติ (8.9.1 Weekly Debt Reminder Scheduler)
```

- **5.1 ประมวลผลและสรุปยอดสถิติแดชบอร์ดและรายปี**:
  - **Input**: *คำขอดูสถิติบิล ภาระหนี้ และรายงานรายเดือน/รายปี* จาก ผู้ใช้งาน (E1)
  - **Data Store**: ดึงข้อมูลบิลจาก **D5 (Bills)** และหนี้จาก **D6 (Debts)**
  - **Business Invariant**:
    - **บิลที่ยกหนี้ให้ครบแล้ว (`isFullyWrittenOff`) จะไม่ถูกนำไปรวมใน "ยอดรวมบิลทั้งหมดที่สร้าง" และ "ยอดรอเก็บ"**
    - **การแชร์สรุปรายปีจะถูกระงับ (Disabled) จนกว่าจะสิ้นสุดปี พ.ศ. นั้นจริง**
  - **Output**: *สถิติยอดบิลที่สร้าง, ยอดเก็บได้แล้ว, ยอดรอเก็บ, จำนวนเพื่อนที่ร่วมหาร, รายงานสรุปค่าใช้จ่าย* แสดงบนหน้าจอ ผู้ใช้งาน (E1)
- **5.2 แสดงไทม์ไลน์และปฏิทินการเงิน**:
  - **Data Store**: ดึงวันที่สร้างบิลจาก **D5** (แสดงจุดสีส้ม) และวันที่เกิดหนี้จาก **D6** (แสดงจุดสีน้ำเงิน)
  - **Output**: *ปฏิทินการเงินและรายการกิจกรรมรายวัน* แสดงผลให้ ผู้ใช้งาน (E1)
- **5.3 ส่งการแจ้งเตือนแบบเรียลไทม์และ Push Notification**:
  - **Input**: *คิวข้อความแจ้งเตือนที่พร้อมส่ง* จาก **D8 (Notifications Outbox)**
  - **External Communication**: ส่ง Push Notification พร้อมรูปภาพผ่าน FCM Service (E6) ไปยังอุปกรณ์ของ ผู้ใช้งาน (E1)
  - **In-App Realtime**: ส่งข้อมูลผ่าน WebSocket (`/realtime`) ไปยังแอปของผู้ใช้ที่กำลังเปิดใช้งาน
  - **Output**: *Push Notification และรายการแจ้งเตือนใน Notification Center*
- **5.4 ประมวลผลรอบเตือนหนี้ประจำสัปดาห์อัตโนมัติ (8.9.1)**:
  - **Logic**: ระบบ Cron/Scheduler ตรวจสอบหนี้ที่ค้างชำระ (`remainingDebt > 0`) ใน **D6 (Debts)** ทุกสัปดาห์ พร้อมคำนวณ `ISO Week Key` (เช่น `2026-W35`)
  - **Deduplication**: ป้องกันการส่งซ้ำในสัปดาห์เดียวกันด้วย `DEBT_WEEKLY_REMINDER:{billItemId}:{weekKey}`
  - **Data Store**: สร้างรายการแจ้งเตือนลง **D8 (Notifications Outbox)** เพื่อให้ Worker ทยอยส่งแจ้งเตือน
  - **Output**: *การแจ้งเตือนยอดค้างชำระรายสัปดาห์ไปยังลูกหนี้*

---

### 🟣 Process 6.0: จัดการร้านค้าและแลกของรางวัล (Rewards Store & Points Redemption)

```
Process 6.0 Sub-processes:
├── 6.1 แสดงรายการของรางวัลและคะแนนสะสม (Rewards Catalog & Points Inquiries)
├── 6.2 ดำเนินการแลกของรางวัลและตัดคะแนน (Reward Item Redemption & Points Deduction)
└── 6.3 ติดตามสถานะการจัดส่งของรางวัล (Reward Delivery & Tracking Updates)
```

- **6.1 แสดงรายการของรางวัลและคะแนนสะสม**:
  - **Input**: *คำขอดูรายการของรางวัลและคะแนนสะสม* จาก ผู้ใช้งาน (E1)
  - **Data Store**: ดึงยอดคะแนนจาก **D1 (User Accounts)** และรายการของรางวัลที่ Active จาก **D9 (Rewards Catalog)**
  - **Output**: *รายการของรางวัล, จำนวนแต้มที่ต้องใช้, จำนวนแต้มคงเหลือ* แสดงบนหน้าจอ ผู้ใช้งาน (E1)
- **6.2 ดำเนินการแลกของรางวัลและตัดคะแนน**:
  - **Input**: *คำขอแลกของรางวัลพร้อมข้อมูลจัดส่ง (ชื่อผู้รับ, เบอร์โทร, ที่อยู่จัดส่ง)* จาก ผู้ใช้งาน (E1)
  - **Data Store**: ตรวจสอบสต็อกใน **D9**, ตัดคะแนนสะสมใน **D1 (User Accounts)**, ลดจำนวนสต็อกสินค้า และบันทึกประวัติการแลกลง **D9 (Rewards Catalog & Redemptions)**
  - **Output**: *ผลการแลกของรางวัลและหลักฐานการทำรายการ* ส่งกลับให้ ผู้ใช้งาน (E1)
- **6.3 ติดตามสถานะการจัดส่งของรางวัล**:
  - **Data Store**: ดึงสถานะการจัดส่ง (Pending Delivery, Shipped, Delivered) และเลข Tracking จาก **D9**
  - **Output**: *สถานะการจัดส่งและเลขพัสดุ* แสดงให้ ผู้ใช้งาน (E1) ตรวจสอบ

---

### ⚫ Process 7.0: จัดการระบบและตรวจสอบความปลอดภัยหลังบ้าน (Back-Office Administration & Developer Console)

```
Process 7.0 Sub-processes:
├── 7.1 ติดตามแดชบอร์ดภาพรวมระบบและสถิติการเงิน (System Dashboard & GMV Analytics)
├── 7.2 จัดการสถานะบัญชีผู้ใช้ (User Management & Account Suspension/Ban)
├── 7.3 ตรวจสอบและระงับข้อพิพาทการเงิน (Dispute Resolution Management)
├── 7.4 ตรวจสอบพฤติกรรมผิดปกติและสลิปซ้ำ (Suspicious Activity & Fraud Oversight)
├── 7.5 ตรวจสอบสมุดบัญชีแยกประเภทและการเงิน (Financial Ledger & Invariant Audit)
├── 7.6 จัดการสต็อกสินค้าของรางวัลและการจัดส่ง (Rewards Store Fulfillment)
└── 7.7 บรอดแคสต์ข้อความแจ้งเตือนและตรวจสอบคิวงาน (Broadcast Notifications & System Controls)
```

- **7.1 ติดตามแดชบอร์ดภาพรวมระบบและสถิติการเงิน**:
  - **Input**: *คำขอดูสถิติระบบและรายงานทางการเงิน* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: ประมวลผลข้อมูลจาก **D1**, **D5**, **D6**, **D10**
  - **Output**: *สถิติภาพรวมระบบ (จำนวนผู้ใช้, ยอด GMV, อัตราความสำเร็จ OCR, สถิติสลิป)* แสดงบนหน้าจอ Developer Console
- **7.2 จัดการสถานะบัญชีผู้ใช้**:
  - **Input**: *คำสั่งระงับ (Suspend), แบน (Ban), หรือปลดแบนบัญชีพร้อมเหตุผล* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: อัปเดตสถานะใน **D1 (User Accounts)** และบันทึก Audit Trail ลง `admin_action_logs` ใน **D10**
  - **Output**: *ผลการจัดการสถานะบัญชีผู้ใช้* ส่งกลับให้ ผู้ดูแลระบบ (E2)
- **7.3 ตรวจสอบและระงับข้อพิพาทการเงิน**:
  - **Input**: *คำสั่งตัดสินข้อพิพาท (Resolved Paid / Written Off / Rejected)* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: อัปเดตสถานะใน `disputes` ใน **D10**, อัปเดตหนี้ใน **D6 (Debts)** และบันทึก Audit Trail ลง **D10**
  - **Output**: *ผลการตัดสินข้อพิพาท* ส่งกลับให้ ผู้ดูแลระบบ (E2)
- **7.4 ตรวจสอบพฤติกรรมผิดปกติและสลิปซ้ำ**:
  - **Input**: *คำขอดูรายการพฤติกรรมน่าสงสัย (Duplicate Slips, Multi-Account IPs)* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: ดึงข้อมูลจาก `suspicious_activity_logs` ใน **D10**
  - **Output**: *รายงานพฤติกรรมผิดปกติและหลักฐานสลิปซ้ำ* แสดงให้ ผู้ดูแลระบบ (E2)
- **7.5 ตรวจสอบสมุดบัญชีแยกประเภทและการเงิน**:
  - **Input**: *คำขอตรวจสอบรายการเคลื่อนไหวทางการเงิน* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: ดึงรายการธุรกรรมจาก `financial_transactions` ใน **D6**
  - **Output**: *รายงานสมุดบัญชีแยกประเภทและการตรวจสอบสมดุลการเงิน* แสดงให้ ผู้ดูแลระบบ (E2)
- **7.6 จัดการสต็อกสินค้าของรางวัลและการจัดส่ง**:
  - **Input**: *คำสั่งเพิ่ม/แก้ไขสินค้าของรางวัล และการอัปเดตเลขพัสดุ (Tracking Number)* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: อัปเดตข้อมูลสินค้าและสถานะการจัดส่งใน **D9 (Rewards Catalog & Redemptions)**
  - **Output**: *ผลการจัดการสินค้าและการจัดส่งของรางวัล* ส่งกลับให้ ผู้ดูแลระบบ (E2)
- **7.7 บรอดแคสต์ข้อความแจ้งเตือนและตรวจสอบคิวงาน**:
  - **Input**: *คำสั่งส่งแจ้งเตือนบรอดแคสต์ (หัวข้อ, ข้อความ, รูปภาพ, กลุ่มเป้าหมาย)* จาก ผู้ดูแลระบบ (E2)
  - **Data Store**: บันทึกข้อความลง **D8 (Notifications Outbox)** เพื่อให้ Worker ส่งผ่าน FCM (E6)
  - **Output**: *สถานะการประมวลผลคิวแจ้งเตือน* ส่งกลับให้ ผู้ดูแลระบบ (E2)

---

## 5. ตารางสรุป Data Flow ทั้งหมดของระบบ (Data Flow Dictionary & Balancing Map)

ตารางนี้ใช้ตรวจสอบ **Data Balancing ระหว่าง Context Diagram, Level 1 DFD และ Level 2 DFD**:

| ชื่อ Data Flow (Concrete Noun Phrase) | แหล่งกำเนิด (Source) | ปลายทาง (Destination) | Process ที่เกี่ยวข้อง (Level 1 / Level 2) | คำอธิบายรายละเอียดข้อมูล |
| :--- | :--- | :--- | :--- | :--- |
| **ข้อมูลการขอเข้าสู่ระบบ Google** | ผู้ใช้งาน (E1) | ระบบ PingPay | 1.0 / 1.1 | Google ID Token หรือ Authorization Code จาก Google Sign-In |
| **คำขอตรวจสอบ Token ภายนอก** | ระบบ PingPay | Google Identity (E3) | 1.0 / 1.1 | Google ID Token สำหรับตรวจสอบความถูกต้องกับ Google OAuth 2.0 |
| **ข้อมูลโปรไฟล์ที่ยืนยันแล้ว** | Google Identity (E3) | ระบบ PingPay | 1.0 / 1.1 | Google Subject ID, Display Name, Email, Profile Picture URL |
| **ข้อมูลการยอมรับนโยบาย PDPA** | ผู้ใช้งาน (E1) | ระบบ PingPay | 1.0 / 1.2 | สถานะยอมรับ, หมายเลขเวอร์ชันนโยบาย (Policy Version), วันเวลา |
| **รหัส PIN และข้อมูลระบุเครื่อง** | ผู้ใช้งาน (E1) | ระบบ PingPay | 1.0 / 1.3, 1.4 | รหัส PIN 6 หลัก, Device UUID, Device Model, OS Version, FCM Token |
| **คำขอรีเซ็ต PIN ผ่านอีเมล** | ผู้ใช้งาน (E1) | ระบบ PingPay | 1.0 / 1.5 | ที่อยู่อีเมลที่ผูกไว้กับบัญชีผู้ใช้ |
| **รหัส OTP ยืนยันตัวตน** | ระบบ PingPay | ระบบส่งอีเมล (E7) | 1.0 / 1.5 | รหัส OTP 6 หลัก พร้อมเวลาหมดอายุ 15 นาที |
| **รหัส OTP ที่กรอกยืนยัน** | ผู้ใช้งาน (E1) | ระบบ PingPay | 1.0 / 1.5 | รหัส OTP 6 หลักที่ผู้ใช้กรอกเพื่อปลดล็อคตั้ง PIN ใหม่ |
| **ข้อมูลชื่อ-นามสกุลจริง** | ผู้ใช้งาน (E1) | ระบบ PingPay | 2.0 / 2.1 | ชื่อและนามสกุลจริงภาษาไทย/อังกฤษสำหรับตรวจสอบกับบัญชีธนาคาร |
| **ข้อมูลช่องทางการรับเงิน** | ผู้ใช้งาน (E1) | ระบบ PingPay | 2.0 / 2.2 | PromptPay ID (เบอร์โทร/บัตร ปชช.), TrueMoney No., ธนาคารและเลขบัญชี |
| **ข้อมูลคำขอเพิ่มเพื่อน/ชื่อเล่น** | ผู้ใช้งาน (E1) | ระบบ PingPay | 2.0 / 2.3, 2.4 | User Code เพื่อน, รูป QR Code ข้อมูลเพื่อน, ชื่อเล่นที่กำหนดเฉพาะบุคคล |
| **ภาพถ่ายใบเสร็จรับเงิน** | ผู้ใช้งาน (E1) | ระบบ PingPay | 3.0 / 3.1 | ไฟล์ภาพถ่ายใบเสร็จค่าใช้จ่าย |
| **คำขอสกัดข้อความใบเสร็จ** | ระบบ PingPay | AI OCR Service (E5) | 3.0 / 3.1 | Image Payload (Base64) หรือ URL รูปภาพใบเสร็จ |
| **รายการสินค้าและราคาจากใบเสร็จ** | AI OCR Service (E5) | ระบบ PingPay | 3.0 / 3.1 | รายการสินค้า, ราคาแต่ละชิ้น, ภาษี, ค่าบริการ, ยอดรวม |
| **ข้อความภาษาธรรมชาติสร้างบิล** | ผู้ใช้งาน (E1) | ระบบ PingPay | 3.0 / 3.2 | ข้อความระบุรายการค่าใช้จ่ายและจำนวนเงิน (NLI Text Input) |
| **ข้อมูลการสร้าง/แก้ไขบิล** | ผู้ใช้งาน (E1) | ระบบ PingPay | 3.0 / 3.3, 3.4 | ชื่อบิล, รายการค่าใช้จ่าย, ผู้ร่วมหาร, สัดส่วนหนี้, หมายเหตุ |
| **คำขอยกเลิกบิล** | ผู้ใช้งาน (E1) | ระบบ PingPay | 3.0 / 3.5 | รหัสบิลและเหตุผลในการขอยกเลิก |
| **คำขอยืนยันยอมรับภาระหนี้** | ผู้ใช้งาน (E1) | ระบบ PingPay | 4.0 / 4.1 | รหัสรายการหนี้และคำสั่งยอมรับภาระหนี้ (Debt Acknowledgement) |
| **คำขอสร้าง QR Code ชำระเงิน** | ระบบ PingPay | EasySlip Service (E4) | 4.0 / 4.2 | รหัส PromptPay/TrueMoney ของเจ้าหนี้ และยอดเงินที่ต้องการโอน |
| **ภาพและข้อมูล Dynamic QR Code** | EasySlip Service (E4) | ระบบ PingPay | 4.0 / 4.2 | Payload สตริง EMVCo และ Base64 QR Image ตรงยอด |
| **ภาพถ่ายสลิปโอนเงินธนาคาร** | ผู้ใช้งาน (E1) | ระบบ PingPay | 4.0 / 4.3 | ไฟล์รูปภาพสลิปการโอนเงินจากแอปธนาคาร |
| **คำขอตรวจสอบสลิปธนาคาร** | ระบบ PingPay | EasySlip Service (E4) | 4.0 / 4.3 | ไฟล์ภาพสลิป และข้อมูลบัญชีผู้รับเงินสำหรับตรวจเทียบ |
| **ผลการตรวจสอบสลิปธนาคาร** | EasySlip Service (E4) | ระบบ PingPay | 4.0 / 4.3 | สถานะความถูกต้อง, ผู้โอน-ผู้รับ, ยอดจริง, วันเวลา, Ref No. |
| **คำสั่งยืนยัน/ปฏิเสธยอดเงิน** | ผู้ใช้งาน (E1) | ระบบ PingPay | 4.0 / 4.4 | คำสั่งอนุมัติตัดยอดหนี้ หรือปฏิเสธสลิปพร้อมเหตุผล |
| **ข้อมูลการขอยกหนี้ให้เพื่อน** | ผู้ใช้งาน (E1) | ระบบ PingPay | 4.0 / 4.6 | รหัสหนี้, จำนวนเงินที่ยกหนี้, เหตุผลในการยกหนี้ |
| **ข้อมูลการแจ้งเตือน Push Notification** | ระบบ PingPay | FCM Service (E6) | 5.0 / 5.3, 5.4 | FCM Payload (หัวข้อ, ข้อความ, รูปภาพ, Token, Deep Link) |
| **การแจ้งเตือนบนหน้าจอมือถือ** | FCM Service (E6) | ผู้ใช้งาน (E1) | 5.0 / 5.3, 5.4 | Heads-up Push Notification แจ้งเตือนบิล, หนี้, สลิป, เตือนรายสัปดาห์ |
| **รายงานสถิติการเงินและไทม์ไลน์** | ระบบ PingPay | ผู้ใช้งาน (E1) | 5.0 / 5.1, 5.2 | สรุปยอดค้าง, สถิติบิลที่สร้าง, ปฏิทินรายวัน, ประวัติรายการ, สรุปรายเดือน/รายปี |
| **คำขอแลกของรางวัลและที่อยู่จัดส่ง** | ผู้ใช้งาน (E1) | ระบบ PingPay | 6.0 / 6.2 | รหัสของรางวัล, จำนวนแต้ม, ชื่อผู้รับ, เบอร์โทร, ที่อยู่จัดส่ง |
| **สถานะการจัดส่งและเลขพัสดุ** | ระบบ PingPay | ผู้ใช้งาน (E1) | 6.0 / 6.3 | สถานะพัสดุและรหัสติดตามพัสดุ (Tracking Number) |
| **คำสั่งจัดการระบบหลังบ้าน** | ผู้ดูแลระบบ (E2) | ระบบ PingPay | 7.0 / 7.2 - 7.7 | คำสั่งระงับบัญชี, ตัดสินข้อพิพาท, จัดการสต็อก, บรอดแคสต์ |
| **รายงานสถิติและข้อมูลตรวจสอบหลังบ้าน** | ระบบ PingPay | ผู้ดูแลระบบ (E2) | 7.0 / 7.1 - 7.6 | สถิติภาพรวม GMV, รายงานข้อพิพาท, สลิปซ้ำ, Audit Logs |

---

## 6. กฎทางธุรกิจและเงื่อนไขความปลอดภัยจริงในระบบ (System Invariants)

1. **สมการความถูกต้องทางการเงิน (Financial Invariant)**:
   $$\text{Current Amount} = \text{Amount Paid} + \text{Amount Written Off} + \text{Outstanding Amount}$$
   - ทุกรายการหนี้ต้องเป็นไปตามสมการนี้เสมอ ไม่มียอดเงินสูญหายหรือเกินจริง
2. **เพดานยอดเงินบิลสูงสุด (Original Amount Ceiling Rule)**:
   $$\text{Current Amount} \le \text{Original Amount}$$
   - ยอดที่สร้างไว้ครั้งแรกจะถูกบันทึกใน `originalTotalAmount` และ `originalAmount` ในฐานข้อมูลถาวร
   - การแก้ไขบิลสามารถปรับลดยอดได้ แต่ **ห้ามปรับเพิ่มเกินกว่ายอดเริ่มต้นเด็ดขาด**
3. **ล็อคการแก้ไข/ยกเลิกบิลเมื่อมีการชำระเงิน (Payment Lock Policy)**:
   - หากบิลหรือรายการหนี้ใดมี `amountPaid > 0` หรือมีการชำระเงินเข้ามาแล้ว **ระบบจะล็อคไม่อนุญาตให้แก้ไขยอดเงิน หรือลบ/ยกเลิกบิลนั้นได้**
4. **การคำนวณยอดบิลในแดชบอร์ด (Excluded Written-Off Bills Calculation)**:
   - บิลที่ยกหนี้ให้ครบแล้ว (`isFullyWrittenOff`) จะ **ไม่ถูกนำมารวมใน "ยอดรวมบิลทั้งหมดที่สร้าง" และ "ยอดรอเก็บ"** เพื่อไม่ให้บิดเบือนกระแสเงินสดจริง แต่ยังคงแสดงในแท็บ *"ยกหนี้แล้ว"* และ *"ทั้งหมด"* เพื่อให้ตรวจสอบประวัติได้
5. **การควบคุมความปลอดภัยอุปกรณ์เดียว (Single Active Device Session Policy)**:
   - บัญชีผู้ใช้สามารถล็อกอินใช้งานได้เพียง **1 อุปกรณ์ในเวลาเดียวกัน** หากมีการล็อกอินจากอุปกรณ์ใหม่ อุปกรณ์เดิมจะถูกบังคับออกจากระบบทันที (`SESSION_TERMINATED`)
6. **การป้องกันสลิปซ้ำ (Duplicate Slip Hash & Reference Protection)**:
   - สลิปทุกใบจะถูกคำนวณ SHA-256 Hash และตรวจสอบกับประวัติสลิปเดิมในระบบ หากพบซ้ำจะปฏิเสธและบันทึกพฤติกรรมน่าสงสัยทันที
7. **ระบบแจ้งเตือนยอดค้างชำระรายสัปดาห์ (8.9.1 Weekly Reminder Cadence)**:
   - ระบบ Worker จะประมวลผลหนี้ที่ยังค้างชำระ (`remainingDebt > 0`) สัปดาห์ละ 1 ครั้ง และใช้คีย์ `DEBT_WEEKLY_REMINDER:{billItemId}:{weekKey}` เพื่อป้องกันการส่งซ้ำซ้อนในสัปดาห์เดียวกัน
