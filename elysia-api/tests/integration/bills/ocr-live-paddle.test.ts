import { describe, it, expect } from "bun:test";
import fs from "fs";
import { PaddleOCRService } from "../../../src/modules/bills/ocr.service";

describe("Live E2E: Real Images with PaddleOCR Container", () => {
  const service = new PaddleOCRService("http://localhost:8866/predict/ocr_system");

  const imagePaths = [
    {
      name: "The Local By Oamthong Thai Cuisine",
      path: "C:\\Users\\ntdotjsx\\.gemini\\antigravity\\brain\\8f801338-0e5e-4eb8-9910-91aae3a61176\\.user_uploaded\\media_1787025247555.jpg",
    },
    {
      name: "Mai Thai Pattaya",
      path: "C:\\Users\\ntdotjsx\\.gemini\\antigravity\\brain\\8f801338-0e5e-4eb8-9910-91aae3a61176\\.user_uploaded\\media_1787025247556.jpg",
    },
    {
      name: "ต๋อง อาหารพื้นเมือง เชียงใหม่",
      path: "C:\\Users\\ntdotjsx\\.gemini\\antigravity\\brain\\8f801338-0e5e-4eb8-9910-91aae3a61176\\.user_uploaded\\media_1787025314114.jpg",
    },
  ];

  for (const img of imagePaths) {
    it(
      `should extract data from real receipt image: ${img.name}`,
      async () => {
        if (!fs.existsSync(img.path)) {
          console.warn(`Skipping live test for ${img.name}: File not found at ${img.path}`);
          return;
        }

        const fileBuffer = fs.readFileSync(img.path);
        const fileBlob = new Blob([fileBuffer], { type: "image/jpeg" });

        const result = await service.extractReceipt(fileBlob);

        console.log(`\n======================================================================`);
        console.log(`🧾 [LIVE OCR RESULT] ${img.name}`);
        console.log(`======================================================================`);
        console.log(`🏪 Merchant : ${result.merchant}`);
        console.log(`💵 Total    : ${result.totalAmount} ${result.currency}`);
        console.log(`🔢 Subtotal : ${result.subtotal} ${result.currency}`);
        if (result.serviceCharge) console.log(`🛎️  Service  : ${result.serviceCharge.amount} THB (${result.serviceCharge.ratePercent || 10}%)`);
        if (result.vat) console.log(`🏛️  VAT      : ${result.vat.amount} THB (${result.vat.ratePercent || 7}%)`);
        if (result.discount) console.log(`🏷️  Discount : ${result.discount} THB`);
        console.log(`📝 Formula  : ${result.formulaExplanation || "N/A"}`);
        console.log(`----------------------------------------------------------------------`);
        console.log(`📦 Line Items (${result.items.length} items):`);
        result.items.forEach((item, idx) => {
          console.log(`   ${(idx + 1).toString().padStart(2, " ")}. ${item.name.padEnd(28, " ")} : ${item.amount.toFixed(2)} THB (qty: ${item.quantity || 1})`);
        });
        console.log(`----------------------------------------------------------------------`);
        console.log(`💾 Database JSON Breakdown (items_breakdown):`);
        console.log(JSON.stringify({
          items: result.items,
          subtotal: result.subtotal,
          service_charge: result.serviceCharge,
          vat: result.vat,
          discount: result.discount,
          total_amount: result.totalAmount,
          formula_explanation: result.formulaExplanation
        }, null, 2));
        console.log(`======================================================================\n`);

        expect(result.currency).toBe("THB");
        expect(result.totalAmount).toBeGreaterThan(0);
        expect(result.items.length).toBeGreaterThan(0);
        expect(result.merchant).toBeDefined();
      },
      60000 // 60s timeout for CPU image inference
    );
  }
});
