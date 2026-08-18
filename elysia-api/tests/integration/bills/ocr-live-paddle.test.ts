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

        console.log(`\n[PaddleOCR Live Result for: ${img.name}]`);
        console.log(`Merchant: ${result.merchant}`);
        console.log(`Total: ${result.totalAmount} ${result.currency}`);
        console.log(`Items count: ${result.items.length}`);

        expect(result.currency).toBe("THB");
        expect(result.totalAmount).toBeGreaterThan(0);
        expect(result.items.length).toBeGreaterThan(0);
        expect(result.merchant).toBeDefined();
      },
      30000 // 30s timeout for full CPU image inference
    );
  }
});
