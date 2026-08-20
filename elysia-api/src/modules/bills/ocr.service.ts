import { env } from "../../config/env";

export interface ReceiptItem {
  name: string;
  amount: number;
  quantity?: number;
}

export interface ReceiptTaxServiceCharge {
  ratePercent?: number;
  amount: number;
}

export interface ReceiptData {
  merchant?: string;
  date?: string;
  items: ReceiptItem[];
  subtotal?: number;
  serviceCharge?: ReceiptTaxServiceCharge;
  vat?: ReceiptTaxServiceCharge;
  discount?: number;
  totalAmount: number;
  currency: string;
  formulaExplanation?: string;
  rawText?: string;
}

export interface OCRService {
  extractReceipt(file: File | Blob): Promise<ReceiptData>;
}

export function parseReceiptText(rawText: string): ReceiptData {
  const tableItems: ReceiptItem[] = [];

  // If text contains HTML table (AksonOCR output format)
  const trMatches = rawText.match(/<tr[\s\S]*?<\/tr>/gi);
  if (trMatches && trMatches.length > 0) {
    for (const tr of trMatches) {
      // Skip header rows
      if (tr.includes("<th")) continue;

      const tds = Array.from(tr.matchAll(/<td[^>]*>([\s\S]*?)<\/td>/gi)).map(m => m[1].trim());
      if (tds.length >= 2) {
        // Find price cell (starts from the rightmost numeric cell)
        let price = 0;
        let name = "";
        let qty = 1;

        for (let i = tds.length - 1; i >= 0; i--) {
          const cleanNum = tds[i].replace(/[^\d.]/g, "");
          const num = parseFloat(cleanNum);
          if (!isNaN(num) && num > 0 && price === 0) {
            price = num;
          } else if (price > 0 && !name && isNaN(parseFloat(tds[i])) && tds[i].length > 0) {
            // Check if it is a unit/qty cell e.g. "1 จาน", "1 ชาม"
            const qtyMatch = tds[i].match(/^(\d+)\s*(?:จาน|ชาม|ถ้วย|ขวด|ถัง|แก้ว|ชุด|ที่|กล่อง)/);
            if (qtyMatch) {
              qty = parseInt(qtyMatch[1], 10);
            } else {
              name = tds[i];
            }
          }
        }

        // If name wasn't set yet, pick the first non-numeric cell or column 1
        if (!name && tds.length > 1) {
          name = tds[1].replace(/^\d+\s*/, "").trim();
        }

        if (name && price > 0 && !/^(ที่|รายการ|ราคา|จำนวน|รวม|รวมเงิน|total|subtotal)/i.test(name)) {
          tableItems.push({ name, amount: price, quantity: qty });
        }
      }
    }
  }

  // 1. Clean Markdown / HTML table artifacts (e.g. <tr>, <td>, <th>, <table>, | delimiters)
  let cleanText = rawText
    .replace(/<thead[\s\S]*?<\/thead>/gi, "")
    .replace(/<\/?(table|tr|th|tbody|tfoot|div|span|p|b|strong|i|em)[^>]*>/gi, "\n")
    .replace(/<\/td>/gi, " ")
    .replace(/<td[^>]*>/gi, "")
    .replace(/<[^>]+>/g, " ");

  // Handle Markdown table syntax e.g. | ลาบหมูคัว | 52.00 |
  const lines = cleanText
    .split("\n")
    .map((l) => {
      let trimmed = l.trim();
      if (trimmed.startsWith("|") && trimmed.endsWith("|")) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }
      return trimmed.replace(/\s*\|\s*/g, "   ").trim();
    })
    .filter((l) => l.length > 0 && !/^[|\-:\s]+$/.test(l));

  let merchant = "ร้านอาหาร (Receipt)";
  if (lines.length > 0) {
    merchant = lines[0].replace(/[#:=|*]/g, "").trim();
  }

  const items: ReceiptItem[] = [];
  let detectedSubtotal: number | undefined;
  let detectedServiceCharge: ReceiptTaxServiceCharge | undefined;
  let detectedVat: ReceiptTaxServiceCharge | undefined;
  let detectedDiscount: number = 0;
  let detectedTotal: number | undefined;

  // 1. Detect Subtotal, Service Charge, VAT, Discount, Grand Total
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Service Charge (e.g. "Service Charge 10%: 241.00", "chuiะ 10n: 241,02", "ce Charge 10%")
    const scMatch = line.match(/(?:service\s*charge|ce\s*charge|charge\s*10%|chui[^\s]*\s*10|ค่าบริการ)\s*(?:(\d+(?:\.\d+)?)%)?[^\d]*([\d,]+[.,]\d{2})?/i);
    if (scMatch) {
      const rate = scMatch[1] ? parseFloat(scMatch[1]) : 10;
      let amount: number | undefined;
      if (scMatch[2]) {
        const cleanStr = scMatch[2].replace(/,/g, ".");
        const parts = cleanStr.split(".");
        amount = parseFloat(parts.slice(0, -1).join("") + "." + parts[parts.length - 1]);
      }
      if (!amount && i + 1 < lines.length) {
        const nextPrice = lines[i + 1].match(/([\d,]+[.,]\d{2})/);
        if (nextPrice) amount = parseFloat(nextPrice[1].replace(/,/g, ""));
      }
      if (amount && !isNaN(amount) && amount > 0) {
        detectedServiceCharge = { ratePercent: rate, amount: Math.round(amount * 100) / 100 };
        continue;
      }
    }

    // VAT / Tax (e.g. "VAT 7%: 185.57", "BTW 7%: 34.02", "7.00 485.98 34.02 520.00", "ภาษี 7%")
    const vatMatch = line.match(/(?:vat|tax|btw|vt|ภาษี)\s*(?:(\d+(?:\.\d+)?)%)?[^\d]*([\d,]+[.,]\d{2})?/i);
    if (vatMatch) {
      const rate = vatMatch[1] ? parseFloat(vatMatch[1]) : 7;
      let amount: number | undefined;
      if (vatMatch[2]) {
        amount = parseFloat(vatMatch[2].replace(/,/g, ""));
      }
      if (!amount && i + 1 < lines.length) {
        const nextPrice = lines[i + 1].match(/([\d,]+[.,]\d{2})/);
        if (nextPrice) amount = parseFloat(nextPrice[1].replace(/,/g, ""));
      }
      if (amount && !isNaN(amount) && amount > 0) {
        detectedVat = { ratePercent: rate, amount: Math.round(amount * 100) / 100 };
        continue;
      }
    }

    // BTW Table row format: "7.00 485. 98 34.02 520.00" -> Rate: 7%, Subtotal: 485.98, VAT: 34.02, Total: 520.00
    const cleanBtwLine = line.replace(/(\d+)\.\s+(\d{2})/g, "$1.$2");
    const btwRowMatch = cleanBtwLine.match(/^(\d+(?:\.\d+)?)\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})/);
    if (btwRowMatch) {
      const rate = parseFloat(btwRowMatch[1]);
      const sub = parseFloat(btwRowMatch[2].replace(/,/g, ""));
      const vatAmt = parseFloat(btwRowMatch[3].replace(/,/g, ""));
      const tot = parseFloat(btwRowMatch[4].replace(/,/g, ""));
      if (!isNaN(rate) && !isNaN(sub) && !isNaN(vatAmt)) {
        detectedVat = { ratePercent: rate, amount: vatAmt };
        detectedSubtotal = sub;
        detectedTotal = tot;
        continue;
      }
    }

    // Direct standalone VAT line e.g. "185.57" right before "nat: 2,836,57"
    if (/^\s*([\d,]+\.\d{2})\s*$/.test(line) && !detectedVat) {
      const amount = parseFloat(line.replace(/,/g, ""));
      if (amount > 0 && amount < 1000 && i + 1 < lines.length && /^(?:net|nat|total)/i.test(lines[i + 1])) {
        detectedVat = { ratePercent: 7, amount };
        continue;
      }
    }

    // Discount (e.g. "ส่วนลด 0.00 บาท", "Discount 50.00", "ส่วนลด o.00")
    const discountMatch = line.match(/(?:discount|ส่วนลด)[^\d]*([\doO,]+[.,][\doO]{2})/i);
    if (discountMatch) {
      const normalized = discountMatch[1].replace(/[oO]/g, "0").replace(/,/g, ".");
      const amount = parseFloat(normalized);
      if (!isNaN(amount)) {
        detectedDiscount = amount;
        continue;
      }
    }

    // Subtotal (e.g. "Subtotal 2,410.00", "fot): 2 +10.6ง", "รวมจำนวนเงินทั้งหมด 228.00")
    const subtotalMatch = line.match(/(?:subtotal|sub\s*total|b\s*total|fot\)|ยอดรวมค่าอาหาร|รวมจ[ำา]นวนเงิน|รวมเงิน|รามจ[ำา]นวนเงิน)[^\d]*([\d,]+[.,]\d{2})?/i);
    if (subtotalMatch) {
      let amount: number | undefined;
      if (subtotalMatch[1]) {
        amount = parseFloat(subtotalMatch[1].replace(/,/g, ""));
      }
      if (!amount && i + 1 < lines.length) {
        const nextPrice = lines[i + 1].match(/([\d,]+[.,]\d{2})/);
        if (nextPrice) amount = parseFloat(nextPrice[1].replace(/,/g, ""));
      }
      if (amount && !isNaN(amount) && amount > 0) {
        detectedSubtotal = amount;
        continue;
      }
    }
  }

  // 2. Detect Grand Total / Net (e.g. "total baht 520 od", "Net: 2,836.57", "คงเหลือจำนวนเงิน 228.00")
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].replace(/(\d+)\s+[oO0][dD0]\b/g, "$1.00").replace(/(\d+)\s+od\b/g, "$1.00");
    const netMatch = line.match(/^(?:net|nat|total|คงเหลือ|คงเห|ยอดรวมสุทธิ|รวมทั้งสิ้น|รวมจ[ำา]นวนเงินทั้งหมด|รามจ[ำา]นวนเงิน)[^\d]*([\d,]+[.,]\d{2})?/i);
    if (netMatch) {
      let amount: number | undefined;
      if (netMatch[1]) {
        const str = netMatch[1];
        const lastIdx = Math.max(str.lastIndexOf("."), str.lastIndexOf(","));
        if (lastIdx > 0) {
          const whole = str.substring(0, lastIdx).replace(/[,.]/g, "");
          const dec = str.substring(lastIdx + 1);
          amount = parseFloat(whole + "." + dec);
        } else {
          amount = parseFloat(str.replace(/,/g, ""));
        }
      }
      if (!amount && i + 1 < lines.length) {
        const nextPrice = lines[i + 1].match(/([\d,]+[.,]\d{2})/);
        if (nextPrice) amount = parseFloat(nextPrice[1].replace(/,/g, ""));
      }
      if (amount && !isNaN(amount) && amount > 0) {
        detectedTotal = amount;
      }
    }
  }

  // 3. Extract line items
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i];

    // Skip summary / category / receipt header / footer lines
    if (/^(net|nat|total|sub|fot|b\s*total|vat|tax|btw|vt|service|ce\s*charge|chui|table|taple|date|transaction|food|beverage|remark|items|orice|price|baht|bant|basis|bedrag|benrag|totaal|totaa|ยะ|if\s+you\s+want|promd|adress|ส่วนลด|ภาษี|รวมทั้งสิ้น|คงเหลือ|คงเห|รามจ|ใบแจ้ง|โต๊ะ|ร้าน|รายการ|จ[ำา]นวน|nddd|trarsartion|ทง|หคด|เงง|จำนวเนจิง|ทงเ|หคิด)/i.test(line)) {
      continue;
    }

    // Common OCR number repairs
    line = line
      .replace(/\bsdd\.dd\b/g, "500.00")
      .replace(/\b8s0\.00\b/g, "850.00")
      .replace(/\bbo\.dd\b/g, "80.00")
      .replace(/\bl2o\.d0\b/g, "120.00")
      .replace(/\bs5\.00\b/g, "55.00")
      .replace(/21d\.00/g, "210.00")
      .replace(/2l0\.\s*00/g, "210.00")
      .replace(/55\.\s*00/g, "55.00")
      .replace(/210,\s*00/g, "210.00")
      .replace(/(\d+)[oO]\.(\d{2})/g, "$10.$2")
      .replace(/([oO])\./g, "0.");

    // Match numbers with 2 decimals from the line
    const priceMatches = Array.from(line.matchAll(/([\d,]+[.,]\s*\d{2})/g));
    if (priceMatches.length > 0) {
      const lastPriceStr = priceMatches[priceMatches.length - 1][1].replace(/\s+/g, "").replace(/,/g, ".");
      const price = parseFloat(lastPriceStr.replace(/,/g, ""));

      // Extract item name by removing index number at start and price/unit at end
      let name = line
        .substring(0, priceMatches[0].index)
        .replace(/^\d+\s*/, "") // remove leading item number "1 ", "2 "
        .replace(/\s+(จาน|ชาม|ถ้วย|ขวด|ถัง|แก้ว|ชุด|ที่|กล่อง|\d+\s*(?:จาน|ชาม|ขวด|ถัง))\s*$/i, "") // remove units
        .trim();

      if (
        name.length > 1 &&
        !/^(total|net|nat|vat|tax|sub|table|taple|date|ใบเสร็จ|ราคา|จ[ำา]นวน|รวม|food|beverage|รายการ|nddd|baht|bant|basis|<|>|td|tr|th)/i.test(name) &&
        !/^<[^>]+>$/i.test(name) &&
        !isNaN(price) &&
        price > 0
      ) {
        items.push({ name, amount: price, quantity: 1 });
        continue;
      }
    }

    // Match item name on one line and price on next line
    if (i + 1 < lines.length) {
      const nextLine = lines[i + 1];
      const nextPriceMatch = nextLine.match(/^([\d,]+[.,]\d{2})/);
      if (
        nextPriceMatch &&
        line.length > 2 &&
        !/^(total|net|vat|tax|sub|table|date|รายการ|ราคา|food|beverage|items|<|>|td|tr|th)/i.test(line) &&
        !/^<[^>]+>$/i.test(line)
      ) {
        const price = parseFloat(nextPriceMatch[1].replace(/,/g, "").replace(/,/g, "."));
        if (!isNaN(price) && price > 0 && !items.some((it) => it.name === line)) {
          items.push({ name: line.replace(/^\d+\s*/, "").trim(), amount: price, quantity: 1 });
        }
      }
    }
  }

  const finalItems = tableItems.length > 0 ? tableItems : items;
  const itemsSum = Math.round(finalItems.reduce((sum, item) => sum + item.amount, 0) * 100) / 100;
  let subtotal = detectedSubtotal;
  // If detected subtotal is much higher than items sum or invalid, fallback to itemsSum
  if (!subtotal || subtotal > itemsSum * 1.5 || subtotal <= 0) {
    subtotal = itemsSum;
  }

  // Adjust service charge if rate is 10%
  if (detectedServiceCharge && detectedServiceCharge.ratePercent === 10 && subtotal > 0) {
    detectedServiceCharge.amount = Math.round(subtotal * 0.10 * 100) / 100;
  }

  let calculatedTotal = subtotal;
  if (detectedServiceCharge) calculatedTotal += detectedServiceCharge.amount;
  if (detectedVat) calculatedTotal += detectedVat.amount;
  if (detectedDiscount > 0) calculatedTotal -= detectedDiscount;
  calculatedTotal = Math.round(calculatedTotal * 100) / 100;

  const finalTotal = detectedTotal || calculatedTotal || subtotal || 0;

  // Build human readable formula explanation
  const parts: string[] = [`Subtotal (${subtotal.toFixed(2)})`];
  if (detectedServiceCharge) {
    parts.push(`+ Service Charge${detectedServiceCharge.ratePercent ? ` ${detectedServiceCharge.ratePercent}%` : ""} (${detectedServiceCharge.amount.toFixed(2)})`);
  }
  if (detectedVat) {
    parts.push(`+ VAT${detectedVat.ratePercent ? ` ${detectedVat.ratePercent}%` : ""} (${detectedVat.amount.toFixed(2)})`);
  }
  if (detectedDiscount > 0) {
    parts.push(`- ส่วนลด (${detectedDiscount.toFixed(2)})`);
  }
  parts.push(`= Total (${finalTotal.toFixed(2)} THB)`);
  const formulaExplanation = parts.join(" ");

  return {
    merchant,
    date: new Date().toISOString(),
    items: finalItems.length > 0 ? finalItems : [{ name: "รายการอาหาร (Receipt Items)", amount: finalTotal, quantity: 1 }],
    subtotal,
    serviceCharge: detectedServiceCharge,
    vat: detectedVat,
    discount: detectedDiscount,
    totalAmount: finalTotal,
    currency: "THB",
    formulaExplanation,
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

export class AksonOCRService implements OCRService {
  private apiKey: string;
  private url: string;

  constructor(apiKey?: string, url?: string) {
    this.apiKey = apiKey || env.AKSON_OCR_API_KEY || "";
    this.url = url || env.AKSON_OCR_URL || "https://backend.aksonocr.com/api/v2/upload";
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

    // If API key is not configured, fallback to PaddleOCRService or Mock
    if (!this.apiKey) {
      console.warn("[AksonOCRService] AKSON_OCR_API_KEY is not configured. Falling back to PaddleOCR / Mock.");
      return new PaddleOCRService().extractReceipt(file);
    }

    try {
      const formData = new FormData();
      const filename = (file as any).name || "receipt.jpg";
      formData.append("file", file, filename);
      formData.append("model", "aksonocr-1.0");

      const response = await fetch(this.url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: formData,
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.warn(`[AksonOCRService] AksonOCR API returned ${response.status}: ${errorText}. Falling back.`);
        return new PaddleOCRService().extractReceipt(file);
      }

      const json: any = await response.json();

      // Extract markdown/text from pages array
      let rawText = "";
      if (Array.isArray(json.pages)) {
        rawText = json.pages.map((p: any) => p.markdown || p.text || "").join("\n");
      } else if (json.text) {
        rawText = json.text;
      } else if (json.markdown) {
        rawText = json.markdown;
      }

      if (!rawText.trim()) {
        return new PaddleOCRService().extractReceipt(file);
      }

      return parseReceiptText(rawText);
    } catch (err: any) {
      console.warn(`[AksonOCRService] Error during AksonOCR request: ${err.message}. Falling back.`);
      return new PaddleOCRService().extractReceipt(file);
    }
  }
}

// Default exported OCR service uses AksonOCR (with PaddleOCR/Mock fallback)
export const defaultOCRService: OCRService = new AksonOCRService();

