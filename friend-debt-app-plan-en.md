# Friend Debt / Bill Splitting App Plan

## USER ROLE

### 1. Onboarding & Authentication
- First-time login: Login via LINE (OAuth)
- Before accessing any feature, the user must go through PDPA Consent first
  - If the user does not tap "Accept", the app closes immediately. No skipping allowed.
- After accepting consent: fill in profile (real name, address, phone number) then set a PIN
- On subsequent logins: enter PIN (biometric login as an optional extra)
- Forgot PIN: re-verify via LINE

Note: Consent must come before collecting any personal data, not after, since entering name and address already counts as collecting personal data.

### 2. Friend Management
- Add a friend by User ID. Both sides must confirm/accept before becoming friends (prevents spam or being added without consent).
- Friends can be removed, but the system must warn the user first if there is still an outstanding debt between them. Silent removal that erases debt evidence is not allowed.

### 3. Creating and Managing Bills
- Create a bill via OCR photo capture or manual entry
- Select which friends are splitting the bill, and adjusting one person's amount auto-adjusts everyone else's amount in the group accordingly
- Editing a bill
  - Can edit the whole bill, or just specific people/specific portions
  - Amounts already fully paid by a person must be locked and cannot be overwritten. If a correction is needed for a paid amount, it must go through a separate refund/adjustment flow, not a silent overwrite.
- Debt write-off
  - Can write off the full amount or a partial amount, and can choose specific people
  - The system must record "written off" separately from "paid" so actual revenue figures are not distorted
- Every time a bill is edited or written off, affected debtors must be notified immediately via LINE, showing a diff (old amount, new amount, who made the change)
- All edits are logged (who changed what, and when)

### 4. Payments
- Pay in full or pay in installments (with a history of each installment)
- Automatic slip verification via SlipOK
- The bill owner must give a second confirmation after SlipOK verification passes (to prevent fake or reused old slips from slipping through)
- Bill status: unpaid / partially paid / fully paid / partially written off / fully written off

### 5. LINE Notifications
- New bill created: notify immediately
- Unpaid debt: send a weekly reminder until paid in full or written off
- Bill edited or written off: notify immediately with a diff
- Payment successful: notify the bill owner to come confirm receipt

---

## DEVELOPER / ADMIN ROLE

1. View all transactions, filterable by user, group, time period, and status
2. View activity logs per user/group
   - Regular logs: auto-deleted every 1 month
   - Flagged/suspicious logs: retained longer, not deleted on the regular schedule (kept as evidence in case of disputes)
3. Ban or temporarily suspend accounts
4. Record suspicious logs, e.g. duplicate slips, multiple accounts from the same IP, unusually frequent write-offs or bill edits
5. Dispute management system: when a debtor claims they already paid but the bill owner has not confirmed receipt, an admin needs a screen to review slips and edit logs to make a determination

---

## Key Adjustments from the Original Spec

| Original | Adjusted To | Reason |
|---|---|---|
| Fill in profile first, then ask for consent | Ask for consent first, always before profile | Correct under PDPA principles |
| Edit bill / write-off with no stated conditions | Lock amounts already paid in full; no overwriting | Prevents disputes over money already paid |
| "Paid" and "written off" mixed together | Separate fields in the system | Keeps actual revenue accurate |
| All logs deleted monthly | Suspicious logs kept separately, not deleted on schedule | Usable for investigation and as evidence later |

---

## Recommended Next Steps

1. Database schema: User, Friend, Bill, BillItem, Payment, EditLog, Dispute tables
2. User flow diagram: from login through bill creation to debt collection
3. Wireframes: main screens (create bill, debt collection view, admin panel)

### Suggested Tech Stack
- Mobile: Flutter
- Backend: Elysia
- Auth: LINE Login + LINE Messaging API (for notifications)
- Payment verification: SlipOK API
- OCR: Google Vision or Typhoon OCR (Thai language support)
