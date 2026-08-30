import { db } from "../../db";
import { friendships, users } from "../../db/schema";
import { eq, and, or } from "drizzle-orm";

export interface NliParsedParticipant {
  userId: string;
  displayName: string;
  customAmount?: number;
  isCustomAmountSpecified: boolean;
}

export interface NliParseResult {
  title: string;
  totalAmount: number;
  matchedParticipants: NliParsedParticipant[];
  unmatchedNames: string[];
  includeOwner: boolean;
  explicitPersonCount?: number;
  rawPrompt: string;
}

export class NliParserService {
  constructor(private customDb: any = db) {}

  private get db() {
    return this.customDb;
  }

  async parsePrompt(userId: string, rawPrompt: string): Promise<NliParseResult> {
    const text = rawPrompt.trim();
    if (!text) {
      return {
        title: "",
        totalAmount: 0,
        matchedParticipants: [],
        unmatchedNames: [],
        includeOwner: true,
        rawPrompt: "",
      };
    }

    // 1. Fetch user's active friends
    const userFriendships = await this.db
      .select({
        friendId: users.id,
        displayName: users.displayName,
        realName: users.realName,
      })
      .from(friendships)
      .innerJoin(
        users,
        or(
          and(eq(friendships.requesterId, userId), eq(users.id, friendships.addresseeId)),
          and(eq(friendships.addresseeId, userId), eq(users.id, friendships.requesterId))
        )
      )
      .where(
        and(
          eq(friendships.status, "accepted"),
          or(eq(friendships.requesterId, userId), eq(friendships.addresseeId, userId))
        )
      );

    // 2. Owner Inclusion / Exclusion
    let includeOwner = true;
    const lowerText = text.toLowerCase();
    if (
      lowerText.includes("ไม่รวมฉัน") ||
      lowerText.includes("ไม่คิดส่วนฉัน") ||
      lowerText.includes("ตัดส่วนฉัน") ||
      lowerText.includes("ออกให้เพื่อน")
    ) {
      includeOwner = false;
    } else if (
      lowerText.includes("รวมฉัน") ||
      lowerText.includes("มีส่วนฉัน") ||
      lowerText.includes("หารฉันด้วย")
    ) {
      includeOwner = true;
    }

    // 3. Explicit Person Count
    let explicitPersonCount: number | undefined;
    const personCountMatch = text.match(/(?:หาร|แชร์|แบ่ง)\s*(?:กัน)?\s*(\d+)\s*(?:คน|ที่)/);
    if (personCountMatch && personCountMatch[1]) {
      explicitPersonCount = parseInt(personCountMatch[1], 10);
    }

    // 4. Extract Total Amount
    let totalAmount = 0;
    const amountRegex = /(?:ยอด|รวม|ราคา|ทั้งหมด)?\s*(?:฿\s*)?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s*(?:บาท|บ\.|฿|\.-)?/g;
    let match: RegExpExecArray | null;
    while ((match = amountRegex.exec(text)) !== null) {
      const numStr = match[1]?.replace(/,/g, "");
      const parsed = parseFloat(numStr || "0");
      if (parsed > 0 && parsed !== explicitPersonCount) {
        if (parsed > totalAmount) {
          totalAmount = parsed;
        }
      }
    }

    // 5. Friend Matching & Custom Amounts
    const matchedParticipants: NliParsedParticipant[] = [];
    const matchedIds = new Set<string>();
    const unmatchedNames: string[] = [];

    // Custom amounts check e.g. "บาส 80 เอ็ม 160"
    const customPattern = /([a-zA-Zก-๙0-9_]+)\s*[:=]?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(?:บาท|บ\.|฿)?/g;
    let customMatch: RegExpExecArray | null;
    while ((customMatch = customPattern.exec(text)) !== null) {
      const namePart = customMatch[1]?.trim() || "";
      const amtPart = parseFloat(customMatch[2] || "0");

      if (
        amtPart > 0 &&
        amtPart !== totalAmount &&
        !["หาร", "แชร์", "รวม", "ราคา", "ยอด", "คน", "ละ"].includes(namePart)
      ) {
        const found = userFriendships.find(
          (f: any) =>
            f.displayName.toLowerCase() === namePart.toLowerCase() ||
            (f.realName && f.realName.toLowerCase() === namePart.toLowerCase())
        );

        if (found && !matchedIds.has(found.friendId)) {
          matchedParticipants.push({
            userId: found.friendId,
            displayName: found.displayName,
            customAmount: amtPart,
            isCustomAmountSpecified: true,
          });
          matchedIds.add(found.friendId);
        }
      }
    }

    // Check direct friend name occurrences in text
    for (const f of userFriendships) {
      if (matchedIds.has(f.friendId)) continue;
      const dName = f.displayName.trim().toLowerCase();
      const rName = (f.realName || "").trim().toLowerCase();

      if (dName && lowerText.includes(dName)) {
        matchedParticipants.push({
          userId: f.friendId,
          displayName: f.displayName,
          isCustomAmountSpecified: false,
        });
        matchedIds.add(f.friendId);
      } else if (rName && rName.length >= 3 && lowerText.includes(rName)) {
        matchedParticipants.push({
          userId: f.friendId,
          displayName: f.displayName,
          isCustomAmountSpecified: false,
        });
        matchedIds.add(f.friendId);
      }
    }

    // Extract Bill Title
    let cleaned = text;
    cleaned = cleaned.replace(/[0-9]+(?:,[0-9]{3})*(?:\.[0-9]+)?/g, "");
    cleaned = cleaned.replace(/(?:บาท|บ\.|฿|\.-)/g, "");
    cleaned = cleaned.replace(/(?:หารกับ|แชร์กับ|หารกัน|หาร|แชร์|แบ่ง|รวมฉัน|ไม่รวมฉัน|ไม่คิดส่วนฉัน|มีส่วนฉัน|คนละ|เท่ากัน|คน|ที่|และ|กับ)/g, " ");
    for (const p of matchedParticipants) {
      cleaned = cleaned.replace(new RegExp(p.displayName, "gi"), " ");
    }
    cleaned = cleaned.replace(/[,:;+\-=_]+/g, " ").replace(/\s+/g, " ").trim();

    const title = cleaned.length >= 2 ? cleaned : "บิลค่าใช้จ่าย";

    return {
      title,
      totalAmount,
      matchedParticipants,
      unmatchedNames,
      includeOwner,
      explicitPersonCount,
      rawPrompt: text,
    };
  }
}
