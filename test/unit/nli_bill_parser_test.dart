import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/bills/models/nli_bill_result_model.dart';
import 'package:pingpay_mobile/features/bills/services/nli_bill_parser.dart';
import 'package:pingpay_mobile/features/friends/models/friend_models.dart';

void main() {
  group('Unit: Natural Language Input (NLI) Thai Bill Parser Tests', () {
    final mockFriends = [
      const FriendUserModel(
        id: 'friend-1',
        userCode: 'USR-BAS',
        displayName: 'ธนพล',
      ),
      const FriendUserModel(
        id: 'friend-2',
        userCode: 'USR-M',
        displayName: 'วสันต์',
      ),
      const FriendUserModel(
        id: 'friend-3',
        userCode: 'USR-KARN',
        displayName: 'กานต์',
      ),
      const FriendUserModel(
        id: 'friend-4',
        userCode: 'USR-SOMCHAI',
        displayName: 'สมชาย',
      ),
    ];

    final customNicknames = {
      'friend-1': 'บาส',
      'friend-2': 'เอ็มมี่',
    };

    test('Parses even split with custom friend nicknames: "กินชาบู 1200 บาท หาร 4 คนกับ บาส เอ็มมี่ กานต์"', () {
      const prompt = 'กินชาบู 1200 บาท หาร 4 คนกับ บาส เอ็มมี่ กานต์';
      final result = NliBillParser.parse(
        prompt,
        mockFriends,
        friendNicknames: customNicknames,
      );

      expect(result.title, 'กินชาบู');
      expect(result.totalAmount, 1200.0);
      expect(result.explicitPersonCount, 4);
      expect(result.includeOwner, true);
      expect(result.matchedParticipants.length, 3);

      final bas = result.matchedParticipants.firstWhere((p) => p.friend.id == 'friend-1');
      expect(bas.effectiveDisplayName, 'บาส');

      final emmy = result.matchedParticipants.firstWhere((p) => p.friend.id == 'friend-2');
      expect(emmy.effectiveDisplayName, 'เอ็มมี่');

      expect(result.totalPeopleCount, 4);
      expect(result.estimatedPerPersonShare, 300.0);
    });

    test('Extracts itemized product list: "กินชาบู 1200 มีเนื้อ 500 ผัก 200 น้ำ 100 หารกับ บาส"', () {
      const prompt = 'กินชาบู 1200 มีเนื้อ 500 ผัก 200 น้ำ 100 หารกับ บาส';
      final result = NliBillParser.parse(
        prompt,
        mockFriends,
        friendNicknames: customNicknames,
      );

      expect(result.totalAmount, 1200.0);
      expect(result.items.length, 3);
      expect(result.items.map((it) => it.name).toList(), containsAll(['เนื้อ', 'ผัก', 'น้ำ']));
      expect(result.items.firstWhere((it) => it.name == 'เนื้อ').amount, 500.0);
      expect(result.items.firstWhere((it) => it.name == 'ผัก').amount, 200.0);
      expect(result.items.firstWhere((it) => it.name == 'น้ำ').amount, 100.0);
    });

    test('Parses custom per-person amounts: "ค่ากาแฟ 240 บาท บาส 80 เอ็มมี่ 160"', () {
      const prompt = 'ค่ากาแฟ 240 บาท บาส 80 เอ็มมี่ 160';
      final result = NliBillParser.parse(
        prompt,
        mockFriends,
        friendNicknames: customNicknames,
      );

      expect(result.title, 'ค่ากาแฟ');
      expect(result.totalAmount, 240.0);
      expect(result.matchedParticipants.length, 2);

      final bas = result.matchedParticipants.firstWhere((p) => p.effectiveDisplayName == 'บาส');
      expect(bas.isCustomAmountSpecified, true);
      expect(bas.customAmount, 80.0);

      final m = result.matchedParticipants.firstWhere((p) => p.effectiveDisplayName == 'เอ็มมี่');
      expect(m.isCustomAmountSpecified, true);
      expect(m.customAmount, 160.0);
    });

    test('Detects exclusion of owner: "ค่าน้ำมัน 800 บาท หารกับ สมชาย ไม่รวมฉัน"', () {
      const prompt = 'ค่าน้ำมัน 800 บาท หารกับ สมชาย ไม่รวมฉัน';
      final result = NliBillParser.parse(
        prompt,
        mockFriends,
        friendNicknames: customNicknames,
      );

      expect(result.title, 'ค่าน้ำมัน');
      expect(result.totalAmount, 800.0);
      expect(result.includeOwner, false);
      expect(result.matchedParticipants.length, 1);
      expect(result.matchedParticipants.first.effectiveDisplayName, 'สมชาย');
    });

    test('Detects Thai currency symbols and Baht variations (฿, .-, บ.)', () {
      const prompt1 = 'ค่าตั๋วหนัง ฿450 หารกับ บาส';
      final result1 = NliBillParser.parse(
        prompt1,
        mockFriends,
        friendNicknames: customNicknames,
      );
      expect(result1.totalAmount, 450.0);
      expect(result1.title, 'ค่าตั๋วหนัง');

      const prompt2 = 'ข้าวกลางวัน 350.- แชร์กับ เอ็มมี่';
      final result2 = NliBillParser.parse(
        prompt2,
        mockFriends,
        friendNicknames: customNicknames,
      );
      expect(result2.totalAmount, 350.0);
    });

    test('Tracks unmatched friend names when friend is not in user friend list', () {
      const prompt = 'กินหมูกระทะ 900 บาท หารกับ บาส และ สมศักดิ์';
      final result = NliBillParser.parse(
        prompt,
        mockFriends,
        friendNicknames: customNicknames,
      );

      expect(result.totalAmount, 900.0);
      expect(result.matchedParticipants.length, 1);
      expect(result.matchedParticipants.first.effectiveDisplayName, 'บาส');
      expect(result.unmatchedNames, contains('สมศักดิ์'));
    });
  });
}
