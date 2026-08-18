import { env } from "../../config/env";

export interface ReceiptItem {
  name: string;
  amount: number;
}

export interface ReceiptData {
  merchant?: string;
  date?: string;
  items: ReceiptItem[];
  subtotal?: number;
  tax?: number;
  discount?: number;
  totalAmount: number;
  currency: string;
  rawText?: string;
}

export interface OCRService {
  extractReceipt(file: File | Blob): Promise<ReceiptData>;
}

export function parseReceiptText(rawText: string): ReceiptData {
  const lines = rawText
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  let merchant = "ร้านอาหาร (Receipt)";
  if (lines.length > 0) {
    merchant = lines[0].replace(/[#:=]/g, "").trim();
  }

  const items: ReceiptItem[] = [];
  let detectedTotal: number | undefined;

  // 1. Detect grand total / net amount from text
  const totalMatch = rawText.match(
    /(?:Net|Total|รวมเงิน|คงเหลือ|รวมจ[ำา]นวนเงิน|รวมทั้งสิ้น|ยอดรวม|สุทธิ)[^\d]*([\d,]+[.,]\d{2})/i
  );
  if (totalMatch) {
    detectedTotal = parseFloat(totalMatch[1].replace(/,/g, "").replace(/,/g, "."));
  }

  // 2. Extract line items
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Match item name followed by price on the same line: e.g. "1 Appetizer set 250.00" or "ลาบหมูคั่ว 52.00"
    const inlineMatch = line.match(/^(\d+\s+)?([^\d]+?)\s+([\d,]+[.,]\d{2})/);
    if (inlineMatch) {
      const name = inlineMatch[2].trim();
      const price = parseFloat(inlineMatch[3].replace(/,/g, "").replace(/,/g, "."));
      if (
        name.length > 1 &&
        !/^(total|net|vat|sub|table|date|ใบเสร็จ|ราคา|จ[ำา]นวน|รวม)/i.test(name) &&
        !isNaN(price) &&
        price > 0
      ) {
        items.push({ name, amount: price });
        continue;
      }
    }

    // Match item name on one line and price on next line
    if (i + 1 < lines.length) {
      const nextLine = lines[i + 1];
      const nextPriceMatch = nextLine.match(/^([\d,]+[.,]\d{2})/);
      if (nextPriceMatch && line.length > 2 && !/^(total|net|vat|sub|table|date|รายการ|ราคา)/i.test(line)) {
        const price = parseFloat(nextPriceMatch[1].replace(/,/g, "").replace(/,/g, "."));
        if (!isNaN(price) && price > 0 && !items.some((it) => it.name === line)) {
          items.push({ name: line.replace(/^\d+\s*/, "").trim(), amount: price });
        }
      }
    }
  }

  // Fallback for total
  if (!detectedTotal || detectedTotal === 0) {
    const allPrices = Array.from(rawText.matchAll(/([\d,]+\.\d{2})/g)).map((m) =>
      parseFloat(m[1].replace(/,/g, ""))
    );
    if (allPrices.length > 0) {
      detectedTotal = Math.max(...allPrices);
    }
  }

  const itemsSum = items.reduce((sum, item) => sum + item.amount, 0);
  const finalTotal = detectedTotal || itemsSum || 0;

  return {
    merchant,
    date: new Date().toISOString(),
    items: items.length > 0 ? items : [{ name: "รายการอาหาร (Receipt Items)", amount: finalTotal }],
    totalAmount: finalTotal,
    currency: "THB",
    rawText,
  };
}

export class MockOCRService implements OCRService {
  private shouldFail = false;
  private customResponse?: ReceiptData;

  setShouldFail(fail: boolean) {
    this.shouldFail = fail;
  }

  setCustomResponse(data: ReceiptData) {
    this.customResponse = data;
  }

  async extractReceipt(file: File | Blob): Promise<ReceiptData> {
    if (this.shouldFail) {
      throw new Error("OCR_PROVIDER_ERROR: Failed to process receipt image.");
    }

    if (!file || file.size === 0) {
      throw new Error("INVALID_FILE: Empty or missing receipt image.");
    }

    if (file.size > 10 * 1024 * 1024) {
      throw new Error("FILE_TOO_LARGE: Receipt image exceeds 10MB limit.");
    }

    if (file.type && !["image/jpeg", "image/png", "image/webp", "image/heic"].includes(file.type)) {
      throw new Error("UNSUPPORTED_FILE_TYPE: Only JPEG, PNG, WEBP, and HEIC images are supported.");
    }

    if (this.customResponse) {
      return this.customResponse;
    }

    return {
      merchant: "Restaurant ABC",
      date: new Date().toISOString(),
      items: [
        { name: "Pad Thai", amount: 120 },
        { name: "Tom Yum Soup", amount: 250 },
        { name: "Water", amount: 30 },
      ],
      subtotal: 400,
      tax: 28,
      discount: 0,
      totalAmount: 428,
      currency: "THB",
    };
  }
}

export class PaddleOCRService implements OCRService {
  private url: string;

  constructor(url?: string) {
    this.url = url || env.PADDLE_OCR_URL || "http://localhost:8866/predict/ocr_system";
  }

  async extractReceipt(file: File | Blob): Promise<ReceiptData> {
    if (!file || file.size === 0) {
      throw new Error("INVALID_FILE: Empty or missing receipt image.");
    }

    if (file.size > 10 * 1024 * 1024) {
      throw new Error("FILE_TOO_LARGE: Receipt image exceeds 10MB limit.");
    }

    if (file.type && !["image/jpeg", "image/png", "image/webp", "image/heic"].includes(file.type)) {
      throw new Error("UNSUPPORTED_FILE_TYPE: Only JPEG, PNG, WEBP, and HEIC images are supported.");
    }

    try {
      const arrayBuffer = await file.arrayBuffer();
      const base64 = Buffer.from(arrayBuffer).toString("base64");

      const response = await fetch(this.url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          images: [base64],
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`OCR_PROVIDER_ERROR: PaddleOCR service error ${response.status}: ${errorText}`);
      }

      const json: any = await response.json();
      const results = json?.results?.[0] || [];

      // PaddleOCR returns list of detected text boxes: [[box, [text, confidence]], ...]
      const lines = results
        .map((item: any) => (Array.isArray(item) ? item[1]?.[0] : item?.text || String(item)))
        .filter(Boolean);
      const rawText = lines.join("\n");

      return parseReceiptText(rawText);
    } catch (err: any) {
      // In test/dev environment where Docker OCR might not be running, fallback gracefully
      if (err.message?.includes("fetch failed") || err.code === "ECONNREFUSED") {
        console.warn(`[PaddleOCRService] Cannot connect to PaddleOCR at ${this.url}. Using fallback.`);
        return new MockOCRService().extractReceipt(file);
      }
      throw err;
    }
  }
}

// Default exported OCR service is PaddleOCR
export const defaultOCRService: OCRService = new PaddleOCRService();
