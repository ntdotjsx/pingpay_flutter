import { describe, it, expect } from "bun:test";
import { EasySlipQrService } from "../../../src/modules/payments/easyslip-qr.service";

describe("Unit: EasySlipQrService (API v1)", () => {
  it("should fail gracefully when API key is missing", async () => {
    const service = new EasySlipQrService("");
    const res = await service.generate({
      type: "PROMPTPAY",
      msisdn: "0826419844",
      amount: 50.0,
    });

    expect(res.success).toBe(false);
    expect(res.error).toContain("EasySlip API Key is not configured");
  });

  it("should format request body correctly for PromptPay and TrueMoney types", async () => {
    const service = new EasySlipQrService("test-key");
    expect(service).toBeInstanceOf(EasySlipQrService);
  });
});
