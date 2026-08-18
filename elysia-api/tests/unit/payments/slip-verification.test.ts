import { describe, it, expect } from "bun:test";
import { SlipOkVerificationService } from "../../../src/modules/payments/slip-verification.service";

describe("Unit: SlipVerificationService with @prakrit_m/slipok-sdk wrapping", () => {
  const service = new SlipOkVerificationService();

  it("should compute deterministic SHA-256 file hashes", () => {
    const buf1 = Buffer.from("mock-slip-image-bytes-1");
    const buf2 = Buffer.from("mock-slip-image-bytes-1");
    const buf3 = Buffer.from("mock-slip-image-bytes-2");

    const hash1 = service.computeFileHash(buf1);
    const hash2 = service.computeFileHash(buf2);
    const hash3 = service.computeFileHash(buf3);

    expect(hash1).toBe(hash2);
    expect(hash1).not.toBe(hash3);
    expect(hash1.length).toBe(64);
  });

  it("should normalize mock and simulated responses", async () => {
    service.setMockResult({
      verified: true,
      amount: 500,
      transactionReference: "SLIPOK-TX-12345",
      sender: { name: "Somchai", account: "081-xxx-1111" },
      receiver: { name: "Sompong", promptPayId: "089-xxx-2222" },
    });

    const res = await service.verify({
      slipFile: Buffer.from("test-slip"),
      expectedAmount: 500,
    });

    expect(res.verified).toBe(true);
    expect(res.amount).toBe(500);
    expect(res.transactionReference).toBe("SLIPOK-TX-12345");
    expect(res.sender?.name).toBe("Somchai");
    expect(res.receiver?.name).toBe("Sompong");
    expect(res.slipHash).toBeDefined();

    service.setMockResult(null, false);
  });
});
