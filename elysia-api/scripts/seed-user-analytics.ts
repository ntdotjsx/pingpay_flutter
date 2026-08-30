import { db } from "../src/db";
import {
  users,
  friendships,
  bills,
  billItems,
  financialTransactions,
} from "../src/db/schema";
import { eq, or, and } from "drizzle-orm";

async function main() {
  console.log("🌱 ========================================================");
  console.log("🌱 [PingPay Seeder] Analytics & Summary Seeder for USR-60CE13");
  console.log("🌱 ========================================================\n");

  // 1. Find or create the target user
  let targetUser = await db.query.users.findFirst({
    where: or(
      eq(users.userCode, "USR-60CE13"),
      eq(users.displayName, "Thanapon Phorarmat")
    ),
  });

  if (!targetUser) {
    const [newUser] = await db
      .insert(users)
      .values({
        userCode: "USR-60CE13",
        displayName: "Thanapon Phorarmat",
        fullName: "Thanapon Phorarmat",
        firstName: "Thanapon",
        lastName: "Phorarmat",
        email: "thanapon.dev@gmail.com",
        phoneNumber: "0812345678",
        promptPayId: "0812345678",
        promptPayIdType: "mobile_number",
        avatarUrl: "https://api.dicebear.com/7.x/avataaars/png?seed=Thanapon",
        accountStatus: "active",
        role: "developer",
        profileCompletedAt: new Date(),
      })
      .returning();
    targetUser = newUser;
    console.log(`➕ Created Target User: ${targetUser.displayName} (${targetUser.userCode})`);
  } else {
    console.log(`👤 Found Target User: ${targetUser.displayName} (${targetUser.userCode}) [ID: ${targetUser.id}]`);
  }

  // 2. Ensure mock friends exist in the database
  const mockFriendSpecs = [
    { code: "USR-0931C3", name: "ป่น (Pon)", phone: "0812345671", avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Pon" },
    { code: "USR-1CE875", name: "Pastis (พาสทิส)", phone: "0812345672", avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Pastis" },
    { code: "USR-77A912", name: "พี่กอล์ฟ (Golf)", phone: "0812345673", avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Golf" },
    { code: "USR-44B881", name: "ศรวิท (Sornwit)", phone: "0812345674", avatar: "https://api.dicebear.com/7.x/avataaars/png?seed=Sornwit" },
  ];

  const friendEntities: any[] = [];

  for (const spec of mockFriendSpecs) {
    let u = await db.query.users.findFirst({
      where: eq(users.userCode, spec.code),
    });

    if (!u) {
      const [newU] = await db
        .insert(users)
        .values({
          userCode: spec.code,
          displayName: spec.name,
          fullName: spec.name,
          phoneNumber: spec.phone,
          promptPayId: spec.phone,
          promptPayIdType: "mobile_number",
          avatarUrl: spec.avatar,
          accountStatus: "active",
          onboardingState: "COMPLETED",
          role: "user",
        })
        .returning();
      u = newU;
      console.log(`  ➕ Created mock friend: ${u.displayName} (${u.userCode})`);
    } else {
      console.log(`  ✓ Found friend: ${u.displayName} (${u.userCode})`);
    }

    friendEntities.push(u);

    // Connect friendship with target user
    const existingFriendship = await db.query.friendships.findFirst({
      where: or(
        and(eq(friendships.requesterId, targetUser.id), eq(friendships.addresseeId, u.id)),
        and(eq(friendships.requesterId, u.id), eq(friendships.addresseeId, targetUser.id))
      ),
    });

    if (!existingFriendship) {
      await db.insert(friendships).values({
        requesterId: u.id,
        addresseeId: targetUser.id,
        status: "accepted",
        respondedAt: new Date(),
      });
      console.log(`    🤝 Established Friendship: ${targetUser.displayName} <-> ${u.displayName}`);
    } else if (existingFriendship.status !== "accepted") {
      await db
        .update(friendships)
        .set({ status: "accepted", respondedAt: new Date() })
        .where(eq(friendships.id, existingFriendship.id));
    }
  }

  const [f1, f2, f3, f4] = friendEntities;

  // 3. Clear old test bills owned by target user or involving target user as debtor
  console.log("\n🧹 Cleaning old test data for target user...");
  const oldUserBills = await db.query.bills.findMany({
    where: eq(bills.ownerId, targetUser.id),
  });

  for (const b of oldUserBills) {
    await db.delete(billItems).where(eq(billItems.billId, b.id));
    await db.delete(bills).where(eq(bills.id, b.id));
  }

  // Also clean old debts where target user is debtor
  await db.delete(billItems).where(eq(billItems.debtorId, targetUser.id));

  console.log("  ✓ Cleared old test bills and items for clean analytics.");

  // 4. Generate 2026 Realistic Financial Data
  console.log("\n📊 Generating 2026 Annual & Monthly Financial Data across 8 Months...\n");

  const year = 2026;

  // Helper to insert bill with items
  async function createBillWithItems(
    title: string,
    totalAmount: number,
    date: Date,
    participants: Array<{ debtor: any; amount: number; paid: number; status: "unpaid" | "partially_paid" | "paid" }>
  ) {
    const isFullyPaid = participants.every((p) => p.paid >= p.amount);
    const hasAnyPaid = participants.some((p) => p.paid > 0);
    const billStatus = isFullyPaid ? "fully_paid" : hasAnyPaid ? "partially_paid" : "unpaid";

    const [newBill] = await db
      .insert(bills)
      .values({
        ownerId: targetUser.id,
        title,
        totalAmount: totalAmount.toFixed(2),
        currency: "THB",
        status: billStatus,
        createdAt: date,
        updatedAt: date,
      })
      .returning();

    for (const p of participants) {
      await db.insert(billItems).values({
        billId: newBill.id,
        debtorId: p.debtor.id,
        originalAmount: p.amount.toFixed(2),
        currentAmount: p.amount.toFixed(2),
        amountPaid: p.paid.toFixed(2),
        amountWrittenOff: "0.00",
        status: p.status,
        isAcknowledged: true,
        createdAt: date,
        updatedAt: date,
      });
    }

    console.log(`  🧾 [บิล ${date.toISOString().substring(0, 10)}] "${title}" ฿${totalAmount.toLocaleString()} (${billStatus})`);
  }

  // Helper to create a debt where targetUser owes friend
  async function createDebtToFriend(
    creditor: any,
    title: string,
    totalAmount: number,
    date: Date,
    myAmount: number,
    myPaid: number
  ) {
    const isPaid = myPaid >= myAmount;
    const isPartiallyPaid = myPaid > 0 && myPaid < myAmount;
    const itemStatus = isPaid ? "paid" : isPartiallyPaid ? "partially_paid" : "unpaid";
    const billStatus = isPaid ? "fully_paid" : isPartiallyPaid ? "partially_paid" : "unpaid";

    const [friendBill] = await db
      .insert(bills)
      .values({
        ownerId: creditor.id,
        title,
        totalAmount: totalAmount.toFixed(2),
        currency: "THB",
        status: billStatus,
        createdAt: date,
        updatedAt: date,
      })
      .returning();

    await db.insert(billItems).values({
      billId: friendBill.id,
      debtorId: targetUser.id,
      originalAmount: myAmount.toFixed(2),
      currentAmount: myAmount.toFixed(2),
      amountPaid: myPaid.toFixed(2),
      amountWrittenOff: "0.00",
      status: itemStatus,
      isAcknowledged: true,
      createdAt: date,
      updatedAt: date,
    });

    console.log(`  💳 [หนี้ ${date.toISOString().substring(0, 10)}] "${title}" จ่ายให้ ${creditor.displayName}: ฿${myPaid}/${myAmount} (${itemStatus})`);
  }

  // --- MONTH 1: JANUARY 2026 (มกราคม) ---
  await createBillWithItems(
    "สังสรรค์ปีใหม่ Rooftop Bar",
    3600.0,
    new Date(year, 0, 5, 19, 30),
    [
      { debtor: f1, amount: 1200.0, paid: 1200.0, status: "paid" },
      { debtor: f2, amount: 1200.0, paid: 1200.0, status: "paid" },
    ]
  );
  await createDebtToFriend(f3, "ค่าที่พักเขาใหญ่ ปีใหม่", 4800.0, new Date(year, 0, 8, 14, 0), 1200.0, 1200.0);

  // --- MONTH 2: FEBRUARY 2026 (กุมภาพันธ์) ---
  await createBillWithItems(
    "ดินเนอร์วาเลนไทน์ Omakase",
    2800.0,
    new Date(year, 1, 14, 18, 0),
    [
      { debtor: f1, amount: 1400.0, paid: 1400.0, status: "paid" },
    ]
  );
  await createDebtToFriend(f2, "ของขวัญวาเลนไทน์รวมกลุ่ม", 900.0, new Date(year, 1, 13, 12, 0), 450.0, 450.0);

  // --- MONTH 3: MARCH 2026 (มีนาคม) ---
  await createBillWithItems(
    "หมูกระทะริมน้ำ สะพานพุทธ",
    1200.0,
    new Date(year, 2, 10, 20, 0),
    [
      { debtor: f1, amount: 400.0, paid: 400.0, status: "paid" },
      { debtor: f2, amount: 400.0, paid: 200.0, status: "partially_paid" },
    ]
  );
  await createBillWithItems(
    "กาแฟ & ขนมหวาน After You",
    540.0,
    new Date(year, 2, 22, 15, 30),
    [
      { debtor: f3, amount: 270.0, paid: 270.0, status: "paid" },
    ]
  );
  await createDebtToFriend(f4, "ค่า Grab Car ไปสนามบินดอนเมือง", 350.0, new Date(year, 2, 28, 9, 0), 350.0, 350.0);

  // --- MONTH 4: APRIL 2026 (เมษายน - สงกรานต์ Peak Month) ---
  await createBillWithItems(
    "ทริปสงกรานต์ พูลวิลล่าพัทยา",
    6800.0,
    new Date(year, 3, 13, 16, 0),
    [
      { debtor: f1, amount: 1700.0, paid: 1700.0, status: "paid" },
      { debtor: f2, amount: 1700.0, paid: 1700.0, status: "paid" },
      { debtor: f3, amount: 1700.0, paid: 1700.0, status: "paid" },
    ]
  );
  await createBillWithItems(
    "อาหารทะเล สดๆ หาดจอมเทียน",
    2400.0,
    new Date(year, 3, 14, 19, 0),
    [
      { debtor: f1, amount: 800.0, paid: 800.0, status: "paid" },
      { debtor: f2, amount: 800.0, paid: 800.0, status: "paid" },
    ]
  );

  // --- MONTH 5: MAY 2026 (พฤษภาคม) ---
  await createBillWithItems(
    "ชาบู ชาบูชิ เซ็นทรัล ลาดพร้าว",
    1596.0,
    new Date(year, 4, 18, 13, 0),
    [
      { debtor: f1, amount: 399.0, paid: 399.0, status: "paid" },
      { debtor: f2, amount: 399.0, paid: 399.0, status: "paid" },
      { debtor: f3, amount: 399.0, paid: 399.0, status: "paid" },
    ]
  );
  await createDebtToFriend(f1, "ตั๋วคอนเสิร์ต Impact Arena", 5000.0, new Date(year, 4, 25, 20, 0), 2500.0, 2500.0);

  // --- MONTH 6: JUNE 2026 (มิถุนายน) ---
  await createBillWithItems(
    "บุฟเฟต์ปิ้งย่างเกาหลี Saemaeul",
    1890.0,
    new Date(year, 5, 12, 18, 30),
    [
      { debtor: f1, amount: 630.0, paid: 630.0, status: "paid" },
      { debtor: f4, amount: 630.0, paid: 630.0, status: "paid" },
    ]
  );
  await createDebtToFriend(f2, "ค่า Grab Food มื้อดึก", 440.0, new Date(year, 5, 20, 23, 0), 220.0, 220.0);

  // --- MONTH 7: JULY 2026 (กรกฎาคม) ---
  await createBillWithItems(
    "ต๋อง อาหารพื้นเมือง นิมมาน เชียงใหม่",
    1450.0,
    new Date(year, 6, 16, 12, 30),
    [
      { debtor: f1, amount: 483.33, paid: 483.33, status: "paid" },
      { debtor: f2, amount: 483.33, paid: 483.33, status: "paid" },
    ]
  );
  await createDebtToFriend(f3, "ค่าตั๋วเครื่องบินไปเชียงใหม่", 3700.0, new Date(year, 6, 15, 8, 0), 1850.0, 1850.0);

  // --- MONTH 8: AUGUST 2026 (สิงหาคม - เดือนปัจจุบัน) ---
  const now = new Date();
  await createBillWithItems(
    "ปาร์ตี้วันเกิด Sushi Den โอมากาเสะ",
    3200.0,
    new Date(now.getFullYear(), now.getMonth(), 8, 19, 0),
    [
      { debtor: f1, amount: 800.0, paid: 800.0, status: "paid" },
      { debtor: f2, amount: 800.0, paid: 800.0, status: "paid" },
      { debtor: f3, amount: 800.0, paid: 0.0, status: "unpaid" },
    ]
  );
  await createBillWithItems(
    "ตั๋วหนัง SF Cinema IMAX",
    900.0,
    new Date(now.getFullYear(), now.getMonth(), 18, 17, 30),
    [
      { debtor: f1, amount: 300.0, paid: 300.0, status: "paid" },
      { debtor: f2, amount: 300.0, paid: 0.0, status: "unpaid" },
    ]
  );
  await createDebtToFriend(f1, "ค่าขนมของฝากจากญี่ปุ่น", 1300.0, new Date(now.getFullYear(), now.getMonth(), 24, 15, 0), 650.0, 0.0);
  await createDebtToFriend(f4, "ค่าแท็กซี่กลับบ้านรอบดึก", 180.0, new Date(now.getFullYear(), now.getMonth(), 27, 23, 30), 180.0, 180.0);

  console.log("\n🎉 ========================================================");
  console.log(`🎉 Mock Financial Analytics generated successfully for ${targetUser.displayName}!`);
  console.log("🎉 Test Now in Flutter App:");
  console.log("   1. เปิดหน้า สรุปค่าใช้จ่าย (Monthly / Yearly Summary)");
  console.log("   2. ดูยอดประจำเดือนสิงหาคม (หรือเลือกดู ม.ค. - ส.ค. 2569)");
  console.log("   3. กดแถบ '📊 สรุปรายปี' เพื่อดูกราฟ 12 เดือน และสถิติทั้งปี 2569!");
  console.log("========================================================\n");

  process.exit(0);
}

main().catch((err) => {
  console.error("❌ Seeding failed with error:", err);
  process.exit(1);
});
