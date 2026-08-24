import { env } from "../../config/env";

export interface EasySlipQrGenerateDto {
  type: "PROMPTPAY" | "KSHOP" | "MAE_MANEE" | "TUNGNGERN" | "TRUEMONEY";
  msisdn?: string;
  natId?: string;
  eWalletId?: string;
  ref1?: string;
  merchantName?: string;
  amount?: number;
}

export interface EasySlipQrResult {
  success: boolean;
  image?: string; // base64 string
  mime?: string;
  payload?: string;
  error?: string;
}

export class EasySlipQrService {
  private apiEndpoint = "https://api.easyslip.com/v1/qr/generate";
  private apiKey: string;

  constructor(apiKey: string = env.EASYSLIP_API_KEY || env.SLIPOK_API_KEY) {
    this.apiKey = apiKey;
  }

  async generate(dto: EasySlipQrGenerateDto): Promise<EasySlipQrResult> {
    if (!this.apiKey) {
      return {
        success: false,
        error: "EasySlip API Key is not configured on server.",
      };
    }

    try {
      // Format payload for EasySlip API
      let reqBody: any = {
        amount: dto.amount && dto.amount > 0 ? Number(dto.amount.toFixed(2)) : undefined,
      };

      if (dto.type === "PROMPTPAY" || dto.type === "TRUEMONEY") {
        reqBody.type = "PROMPTPAY";
        if (dto.msisdn) {
          const cleanPhone = dto.msisdn.replace(/[^0-9]/g, "");
          if (cleanPhone.length === 10) {
            reqBody.msisdn = cleanPhone;
          } else if (cleanPhone.length === 13) {
            reqBody.natId = cleanPhone;
          } else if (cleanPhone.length === 15) {
            reqBody.eWalletId = cleanPhone;
          } else {
            reqBody.msisdn = cleanPhone;
          }
        } else if (dto.natId) {
          reqBody.natId = dto.natId.replace(/[^0-9]/g, "");
        } else if (dto.eWalletId) {
          reqBody.eWalletId = dto.eWalletId.replace(/[^0-9]/g, "");
        }
      } else {
        reqBody.type = dto.type;
        reqBody.ref1 = dto.ref1;
        if (dto.merchantName) reqBody.merchantName = dto.merchantName;
      }

      const res = await fetch(this.apiEndpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(reqBody),
      });

      const json = await res.json().catch(() => null);

      if (!res.ok || !json || (json.status !== 200 && json.status !== "200") || !json.data) {
        const errorMsg = json?.message || json?.error || `EasySlip QR generate failed (Status ${res.status})`;
        return {
          success: false,
          error: errorMsg,
        };
      }

      return {
        success: true,
        image: json.data.image,
        mime: json.data.mime || "image/png",
        payload: json.data.payload,
      };
    } catch (err: any) {
      console.error("[EasySlipQrService] error:", err);
      return {
        success: false,
        error: err?.message || "Network error while calling EasySlip QR service.",
      };
    }
  }
}

export const defaultEasySlipQrService = new EasySlipQrService();
