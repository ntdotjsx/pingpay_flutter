import crypto from "crypto";
import SlipOk from "@prakrit_m/slipok-sdk";
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

export class SlipOkVerificationService implements SlipVerificationService {
  private slipOk: SlipOk | null = null;
  private mockMode: boolean = false;
  private mockResult: Partial<SlipVerificationResult> | null = null;

  constructor(apiKey: string = env.SLIPOK_API_KEY, branchId: string = env.SLIPOK_BRANCH_ID) {
    if (apiKey && branchId) {
      this.slipOk = new SlipOk(apiKey, branchId, {
        timeout: 8000,
        retries: 1,
      });
    }
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
            "SLIP-REF-" + Math.random().toString(36).substring(2, 9).toUpperCase()
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

    // Production SlipOK SDK Integration
    if (!this.slipOk) {
      // Fallback in case no credentials configured: simulation mode for test environments
      if (!input.qrData && !fileBuffer) {
        return {
          verified: false,
          failureCode: "NO_PAYLOAD",
          failureMessage: "Neither slip image nor QR data was provided.",
          slipHash,
        };
      }

      // Default safe simulation for unconfigured dev environment
      return {
        verified: true,
        transactionReference: "SIMULATED-REF-" + (slipHash ? slipHash.substring(0, 12) : "QR"),
        amount: input.expectedAmount || 100,
        sender: { name: "Test Payer" },
        receiver: {
          promptPayId: input.expectedReceiverPromptPay,
          account: input.expectedReceiverAccount,
        },
        transactionDate: new Date(),
        slipHash,
        rawResponse: { simulated: true },
      };
    }

    try {
      let response: any;
      if (input.qrData) {
        response = await this.slipOk.checkSlip({
          data: input.qrData,
          log: true,
        });
      } else if (fileBuffer) {
        // Use base64 or buffer url
        const b64 = fileBuffer.toString("base64");
        response = await this.slipOk.checkSlip({
          data: b64,
          log: true,
        });
      } else {
        return {
          verified: false,
          failureCode: "MISSING_INPUT",
          failureMessage: "No file or QR payload provided.",
          slipHash,
        };
      }

      if (!response || !response.success || !response.data) {
        return {
          verified: false,
          failureCode: response?.code || "SLIP_VERIFICATION_FAILED",
          failureMessage: response?.message || "SlipOK was unable to verify this slip.",
          slipHash,
          rawResponse: response,
        };
      }

      const data = response.data;
      const verifiedAmount = parseFloat(data.amount || "0");
      const transactionRef = data.transRef || data.id || `SLIPOK-${Date.now()}`;
      const sender = {
        name: data.sender?.name?.th || data.sender?.name?.en || data.sender?.displayName,
        account: data.sender?.account?.value,
        bank: data.sender?.bank?.short,
      };
      const receiver = {
        name: data.receiver?.name?.th || data.receiver?.name?.en || data.receiver?.displayName,
        account: data.receiver?.account?.value,
        bank: data.receiver?.bank?.short,
        promptPayId: data.receiver?.proxy?.value,
      };

      return {
        verified: true,
        transactionReference: transactionRef,
        amount: verifiedAmount,
        sender,
        receiver,
        transactionDate: data.transDate ? new Date(data.transDate) : new Date(),
        slipHash,
        rawResponse: data,
      };
    } catch (err: any) {
      console.error("[SlipOkVerificationService] Provider error:", err);
      return {
        verified: false,
        failureCode: "SLIP_VERIFICATION_UNAVAILABLE",
        failureMessage: `SlipOK service error: ${err?.message || "Network or Provider Failure"}`,
        slipHash,
      };
    }
  }
}

export const defaultSlipVerificationService = new SlipOkVerificationService();
