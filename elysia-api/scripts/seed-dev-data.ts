import { db } from "../src/db";
import {
  users,
  userCredentials,
  authIdentities,
  consentRecords,
  friendships,
  bills,
  billItems,
  financialTransactions,
  editLogs,
} from "../src/db/schema";
import { eq, or, and, ne } from "drizzle-orm";
import argon2 from "argon2";

async function main() {
  console.log("🌱 ========================================================");
  console.log("🌱 [PingPay Dev Seeder] Dynamic Real-User Seeder");
  console.log("🌱 ========================================================\n");

  // 1. Fetch all real users currently in the database
  const allUsers = await db.query.users.findMany({
    orderBy: (u: any, { asc }: any) => [asc(u.createdAt)],
  });

  if (allUsers.length === 0) {
    console.log("❌ No users found in database. Please log in through the app once first.");
    process.exit(1);
  }

  // Identify Developer / Logged-in User (e.g. Nut Thanapon or role: developer)
  let mainUser = allUsers.find((u) => u.role === "developer" || u.displayName?.includes("Nut")) || allUsers[0];

  console.log(`👤 Main User: ${mainUser.displayName} (${mainUser.userCode}) [ID: ${mainUser.id}]`);

  // Other real users in the DB (e.g. ggolf, ศรวิท, etc.)
  const otherUsers = allUsers.filter((u) => u.id !== mainUser.id);
  console.log(`👥 Found ${otherUsers.length} other user(s) in database:`);
  otherUsers.forEach((u, i) => {
    console.log(`   ${i + 1}. ${u.displayName ?? "No Name"} (${u.userCode}) [ID: ${u.id}]`);
  });

  // 2. Ensure friendships exist between mainUser and all other users in DB
  console.log("\n🤝 Ensuring Friendships between all DB users...");
  for (const other of otherUsers) {
    const existing = await db.query.friendships.findFirst({
      where: or(
        and(eq(friendships.requesterId, mainUser.id), eq(friendships.addresseeId, other.id)),
        and(eq(friendships.requesterId, other.id), eq(friendships.addresseeId, mainUser.id))
      ),
    });

    if (!existing) {
      await db.insert(friendships).values({
        requesterId: other.id,
        addresseeId: mainUser.id,
        status: "accepted",
        respondedAt: new Date(),
      });
      console.log(`  ➕ Connected Friend: ${mainUser.displayName} <-> ${other.displayName}`);
    } else if (existing.status !== "accepted") {
      await db
        .update(friendships)
        .set({ status: "accepted", respondedAt: new Date() })
        .where(eq(friendships.id, existing.id));
      console.log(`  ✓ Accepted Friendship: ${mainUser.displayName} <-> ${other.displayName}`);
    } else {
      console.log(`  ✓ Already Friends: ${mainUser.displayName} <-> ${other.displayName}`);
    }
  }

  // 3. Ensure each user has a PromptPay ID for testing QR payments
  for (const u of allUsers) {
    if (!u.promptPayId) {
      const mockPhone = "08" + Math.floor(10000000 + Math.random() * 90000000);
      await db
        .update(users)
        .set({
          promptPayId: mockPhone,
          promptPayIdType: "mobile_number",
          phoneNumber: mockPhone,
        })
        .where(eq(users.id, u.id));
      console.log(`  💳 Set default PromptPay (${mockPhone}) for: ${u.displayName}`);
    }
  }

  // 4. Create Scenario Bills using REAL DB USERS
  console.log("\n💳 ========================================================");
  console.log("💳 Generating Live Test Scenarios with Real DB Users...");
  console.log("💳 ========================================================\n");

  // Pick up to 3 friends from the database
  const friend1 = otherUsers[0] || mainUser;
  const friend2 = otherUsers[1] || friend1;
  const friend3 = otherUsers[2] || friend2;

  // --------------------------------------------------------------------------
  // SCENARIO 1: DEBTS YOU OWE TO REAL FRIENDS (เราติดเพื่อน)
  // --------------------------------------------------------------------------
  console.log("📌 Scenario 1: Debts YOU OWE to real DB friends (เราติดเพื่อน):");

  // 1.1 Friend 1 created a bill for หมูกระทะ (We owe ฿320.00)
  if (friend1.id !== mainUser.id) {
    const [bill1] = await db
      .insert(bills)
      .values({
        ownerId: friend1.id,
        title: "หมูกระทะริมน้ำ สะพานพุทธ",
        totalAmount: "640.00",
        currency: "THB",
        status: "unpaid",
        createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
      })
      .returning();

    await db.insert(billItems).values({
      billId: bill1.id,
      debtorId: mainUser.id,
      originalAmount: "320.00",
      currentAmount: "320.00",
      amountPaid: "0.00",
      amountWrittenOff: "0.00",
      status: "unpaid",
    });

    console.log(`  🍖 [บิลที่ 1] "${bill1.title}" โดย ${friend1.displayName}`);
    console.log(`     👉 คุณต้องจ่ายให้ ${friend1.displayName}: ฿320.00 (ยังไม่ชำระ)`);
  }

  // 1.2 Friend 2 created a bill for ค่า Grab Car (We owe ฿150.00 - partially paid ฿50)
  if (friend2.id !== mainUser.id) {
    const [bill2] = await db
      .insert(bills)
      .values({
        ownerId: friend2.id,
        title: "ค่า Grab Car ไปงานเลี้ยง",
        totalAmount: "300.00",
        currency: "THB",
        status: "partially_paid",
        createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000), // 4 days ago
      })
      .returning();

    await db.insert(billItems).values({
      billId: bill2.id,
      debtorId: mainUser.id,
      originalAmount: "150.00",
      currentAmount: "150.00",
      amountPaid: "50.00",
      amountWrittenOff: "0.00",
      status: "partially_paid",
    });

    console.log(`  🚗 [บิลที่ 2] "${bill2.title}" โดย ${friend2.displayName}`);
    console.log(`     👉 คุณต้องจ่ายให้ ${friend2.displayName}: คงค้าง ฿100.00 (จ่ายแล้ว ฿50 จาก ฿150)`);
  }

  // --------------------------------------------------------------------------
  // SCENARIO 2: DEBTS REAL FRIENDS OWE YOU (เพื่อนติดเรา / รอรับเงินคืน)
  // --------------------------------------------------------------------------
  console.log("\n📌 Scenario 2: Debts REAL DB FRIENDS OWE YOU (เพื่อนติดเรา):");

  // 2.1 You created a bill for ต๋อง อาหารพื้นเมือง
  if (friend1.id !== mainUser.id || friend2.id !== mainUser.id) {
    const [bill3] = await db
      .insert(bills)
      .values({
        ownerId: mainUser.id,
        title: "ต๋อง อาหารพื้นเมือง นิมมาน",
        totalAmount: "450.00",
        currency: "THB",
        status: "unpaid",
        createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // 1 day ago
      })
      .returning();

    if (friend1.id !== mainUser.id) {
      await db.insert(billItems).values({
        billId: bill3.id,
        debtorId: friend1.id,
        originalAmount: "225.00",
        currentAmount: "225.00",
        amountPaid: "0.00",
        amountWrittenOff: "0.00",
        status: "unpaid",
      });
      console.log(`  🍜 [บิลที่ 3] "${bill3.title}" (คุณเป็นเจ้าของ)`);
      console.log(`     👉 ${friend1.displayName} ค้างคุณ: ฿225.00`);
    }

    if (friend2.id !== mainUser.id && friend2.id !== friend1.id) {
      await db.insert(billItems).values({
        billId: bill3.id,
        debtorId: friend2.id,
        originalAmount: "225.00",
        currentAmount: "225.00",
        amountPaid: "0.00",
        amountWrittenOff: "0.00",
        status: "unpaid",
      });
      console.log(`     👉 ${friend2.displayName} ค้างคุณ: ฿225.00`);
    }
  }

  // 2.2 You created a bill for วันนี้ (ชาบู ชาบูชิ)
  if (friend3.id !== mainUser.id) {
    const [bill4] = await db
      .insert(bills)
      .values({
        ownerId: mainUser.id,
        title: "ชาบู ชาบูชิ เซ็นทรัล",
        totalAmount: "399.00",
        currency: "THB",
        status: "unpaid",
        createdAt: new Date(), // Today
      })
      .returning();

    await db.insert(billItems).values({
      billId: bill4.id,
      debtorId: friend3.id,
      originalAmount: "399.00",
      currentAmount: "399.00",
      amountPaid: "0.00",
      amountWrittenOff: "0.00",
      status: "unpaid",
    });

    console.log(`  🍲 [บิลที่ 4] "${bill4.title}" (คุณเป็นเจ้าของ วันนี้)`);
    console.log(`     👉 ${friend3.displayName} ค้างคุณ: ฿399.00`);
  }

  console.log("\n🎉 ========================================================");
  console.log("🎉 Seed Finished Successfully with Real DB Users!");
  console.log("🎉 Test Now in Flutter App:");
  console.log("   1. [หน้าหลัก] กดแถบ 'เราติดเพื่อน' และ 'เพื่อนติดเรา'");
  console.log("   2. [PromptPay QR] ลองกดเปิดดู QR Code ของเพื่อนจริง");
  console.log("   3. [เพื่อน] รายชื่อเพื่อนจริงในระบบจะเชื่อมต่อกันครบถ้วน");
  console.log("========================================================\n");

  process.exit(0);
}

main().catch((err) => {
  console.error("❌ Seeding failed with error:", err);
  process.exit(1);
});

