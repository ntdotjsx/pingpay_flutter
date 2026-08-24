import crypto from "crypto";
import { env } from "../../config/env";

export interface SlipVerificationInput {
  slipFile?: Blob | Buffer;
  qrData?: string;
  expectedAmount?: number;
  expectedReceiverPromptPay?: string;
  expectedReceiverAccount?: string;
}

export interface NormalizedSlipParty {
  displayName?: string;
  name?: string;
  account?: string;
  bank?: string;
  promptPayId?: string;
}

export interface SlipVerificationResult {
  verified: boolean;
  transactionReference?: string;
  amount?: number;
  sender?: NormalizedSlipParty;
  receiver?: NormalizedSlipParty;
  transactionDate?: Date;
  slipHash?: string;
  failureCode?: string;
  failureMessage?: string;
  rawResponse?: any;
}

export interface SlipVerificationService {
  computeFileHash(buffer: Buffer): string;
  verify(input: SlipVerificationInput): Promise<SlipVerificationResult>;
}

/**
 * EasySlip API v2 Verification Service
 * Docs: https://document.easyslip.com/th/v2/verify/bank/
 * Endpoint: POST https://api.easyslip.com/v2/verify/bank
 */
export class EasySlipVerificationService implements SlipVerificationService {
  private apiKey: string;
  private apiEndpoint: string = "https://api.easyslip.com/v2/verify/bank";
  private mockMode: boolean = false;
  private mockResult: Partial<SlipVerificationResult> | null = null;

  constructor(apiKey: string = env.EASYSLIP_API_KEY || env.SLIPOK_API_KEY) {
    this.apiKey = apiKey || "";
  }

  setMockResult(result: Partial<SlipVerificationResult> | null, enabled: boolean = true) {
    this.mockMode = enabled;
    this.mockResult = result;
  }

  computeFileHash(buffer: Buffer): string {
    return crypto.createHash("sha256").update(buffer).digest("hex");
  }

  async verify(input: SlipVerificationInput): Promise<SlipVerificationResult> {
    let fileBuffer: Buffer | null = null;
    let slipHash: string | undefined = undefined;

    if (input.slipFile) {
      if (input.slipFile instanceof Buffer) {
        fileBuffer = input.slipFile;
      } else {
        const ab = await input.slipFile.arrayBuffer();
        fileBuffer = Buffer.from(ab);
      }
      slipHash = this.computeFileHash(fileBuffer);
    }

    // Return mock verification if enabled (for unit & integration tests)
    if (this.mockMode && this.mockResult) {
      const isVerified = this.mockResult.verified === true;
      return {
        verified: isVerified,
        transactionReference: isVerified
          ? this.mockResult.transactionReference ||
            "EASYSLIP-REF-" + Math.random().toString(36).substring(2, 9).toUpperCase()
          : undefined,
        amount: isVerified ? (this.mockResult.amount ?? input.expectedAmount ?? 100) : undefined,
        sender: isVerified
          ? this.mockResult.sender || { name: "Mock Payer", account: "xxx-xxx-1234" }
          : undefined,
        receiver: isVerified
          ? this.mockResult.receiver || {
              name: "Mock Owner",
              promptPayId: input.expectedReceiverPromptPay || "0812345678",
              account: input.expectedReceiverAccount || "xxx-xxx-5678",
            }
          : undefined,
        transactionDate: this.mockResult.transactionDate || new Date(),
        slipHash,
        failureCode: this.mockResult.failureCode,
        failureMessage: this.mockResult.failureMessage,
        rawResponse: this.mockResult.rawResponse || { mock: true },
      };
    }

    // Strict EasySlip Integration (Reject if API key not configured)
    if (!this.apiKey) {
      return {
        verified: false,
        failureCode: "EASYSLIP_NOT_CONFIGURED",
        failureMessage: "EasySlip API Key is not configured on server.",
        slipHash,
      };
    }

    try {
      let response: Response;

      if (input.qrData) {
        // Send QR Payload as JSON
        response = await fetch(this.apiEndpoint, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            payload: input.qrData,
          }),
        });
      } else if (fileBuffer) {
        // Send image file as multipart/form-data
        const formData = new FormData();
        const blob = new Blob([fileBuffer], { type: "image/jpeg" });
        formData.append("image", blob, "slip.jpg");

        response = await fetch(this.apiEndpoint, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
          },
          body: formData,
        });
      } else {
        return {
          verified: false,
          failureCode: "MISSING_INPUT",
          failureMessage: "No file or QR payload provided.",
          slipHash,
        };
      }

      const json = await response.json().catch(() => null);

      if (!response.ok || !json || json.success !== true || !json.data) {
        const errCode = json?.error?.code || json?.code || (response.status === 404 ? "SLIP_NOT_FOUND" : "SLIP_VERIFICATION_FAILED");
        const errMsg = json?.error?.message || json?.message || `EasySlip verification failed (Status ${response.status}).`;

        return {
          verified: false,
          failureCode: errCode,
          failureMessage: errMsg,
          slipHash,
          rawResponse: json,
        };
      }

      const data = json.data;
      const raw = data.rawSlip || data;

      // Extract verified amount (EasySlip provides amountInSlip or rawSlip.amount.amount)
      let verifiedAmount = 0;
      if (typeof data.amountInSlip === "number") {
        verifiedAmount = data.amountInSlip;
      } else if (typeof raw.amount === "number") {
        verifiedAmount = raw.amount;
      } else if (raw.amount?.amount !== undefined) {
        verifiedAmount = typeof raw.amount.amount === "number" ? raw.amount.amount : parseFloat(raw.amount.amount || "0");
      }

      // Extract transaction reference
      const transactionRef = raw.transRef || raw.transactionReference || data.transRef || data.id || `EASYSLIP-${Date.now()}`;

      // Extract Sender Info
      const sender: NormalizedSlipParty = {
        name: raw.sender?.account?.name?.th || raw.sender?.account?.name?.en || raw.sender?.name?.th || raw.sender?.name?.en || raw.sender?.displayName,
        account: raw.sender?.account?.bank?.account || raw.sender?.account?.proxy?.account || raw.sender?.account?.value,
        bank: raw.sender?.bank?.short || raw.sender?.bank?.shortCode || raw.sender?.bank?.name,
      };

      // Extract Receiver Info
      const receiver: NormalizedSlipParty = {
        name: raw.receiver?.account?.name?.th || raw.receiver?.account?.name?.en || raw.receiver?.name?.th || raw.receiver?.name?.en || raw.receiver?.displayName,
        account: raw.receiver?.account?.bank?.account || raw.receiver?.account?.proxy?.account || raw.receiver?.account?.value,
        bank: raw.receiver?.bank?.short || raw.receiver?.bank?.shortCode || raw.receiver?.bank?.name,
        promptPayId: raw.receiver?.account?.proxy?.account || raw.receiver?.proxy?.value || raw.receiver?.proxy?.account,
      };

      // Extract Transaction Date
      let transactionDate = new Date();
      if (raw.date) {
        transactionDate = new Date(raw.date);
      } else if (raw.transDate) {
        transactionDate = new Date(raw.transDate);
      }

      return {
        verified: true,
        transactionReference: transactionRef,
        amount: verifiedAmount,
        sender,
        receiver,
        transactionDate,
        slipHash,
        rawResponse: data,
      };
    } catch (err: any) {
      console.error("[EasySlipVerificationService] Provider error:", err);
      return {
        verified: false,
        failureCode: "SLIP_VERIFICATION_UNAVAILABLE",
        failureMessage: `EasySlip service error: ${err?.message || "Network or Provider Failure"}`,
        slipHash,
      };
    }
  }
}

// Backward compatibility alias for SlipOK imports
export class SlipOkVerificationService extends EasySlipVerificationService {}

export const defaultSlipVerificationService = new EasySlipVerificationService();
