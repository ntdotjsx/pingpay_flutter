import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/features/friends/providers/friend_nickname_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FriendNicknameNotifier Client-Side Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'pingpay_friend_nickname_USR-0931C3': 'ต๋อง DevOps',
      });
    });

    test('Loads pre-existing nicknames from SharedPreferences on init', () async {
      final notifier = FriendNicknameNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.getNickname(userCode: 'USR-0931C3'), 'ต๋อง DevOps');
      expect(
        notifier.getEffectiveName(userCode: 'USR-0931C3', defaultName: 'ntdotjsx'),
        'ต๋อง DevOps',
      );
      expect(
        notifier.getEffectiveName(userId: 'USR-UNKNOWN', defaultName: 'Default User'),
        'Default User',
      );
    });

    test('Sets and removes nickname locally without server', () async {
      final notifier = FriendNicknameNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      await notifier.setNickname(userId: 'uuid-123', userCode: 'USR-TEST-1', nickname: 'น้องมายด์');
      expect(notifier.getNickname(userId: 'uuid-123'), 'น้องมายด์');
      expect(notifier.getNickname(userCode: 'USR-TEST-1'), 'น้องมายด์');
      expect(
        notifier.getEffectiveName(userId: 'uuid-123', defaultName: 'Real Name'),
        'น้องมายด์',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pingpay_friend_nickname_uuid-123'), 'น้องมายด์');
      expect(prefs.getString('pingpay_friend_nickname_USR-TEST-1'), 'น้องมายด์');

      await notifier.removeNickname(userId: 'uuid-123', userCode: 'USR-TEST-1');
      expect(notifier.getNickname(userId: 'uuid-123'), null);
      expect(notifier.getNickname(userCode: 'USR-TEST-1'), null);
      expect(prefs.getString('pingpay_friend_nickname_uuid-123'), null);
      expect(prefs.getString('pingpay_friend_nickname_USR-TEST-1'), null);
    });
  });
}
