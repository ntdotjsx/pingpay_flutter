import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingpay_mobile/core/theme/theme.dart';
import 'package:pingpay_mobile/features/friends/models/friend_models.dart';
import 'package:pingpay_mobile/features/friends/providers/friend_nickname_provider.dart';
import 'package:pingpay_mobile/features/friends/providers/friends_provider.dart';
import 'package:pingpay_mobile/features/friends/screens/friends_screen.dart';
import 'package:pingpay_mobile/features/friends/screens/add_friend_screen.dart';

void main() {
  group('Feature 2: Friends Widget & Flow Tests', () {
    testWidgets(
      'FriendsScreen renders tabs and empty state when no friends exist',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              friendsListProvider.overrideWith((ref) async => []),
              incomingFriendRequestsProvider.overrideWith((ref) async => []),
              outgoingFriendRequestsProvider.overrideWith((ref) async => []),
            ],
            child: MaterialApp(
              theme: LightTheme.theme,
              home: const FriendsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check header and tabs
        expect(find.text('เพื่อน (Friends)'), findsOneWidget);
        expect(find.text('เพื่อนของฉัน'), findsOneWidget);
        expect(find.text('คำขอเข้า'), findsOneWidget);
        expect(find.text('คำขอที่ส่ง'), findsOneWidget);

        // Check empty state
        expect(find.text('ยังไม่มีเพื่อนในระบบ'), findsOneWidget);
        expect(find.text('+ เพิ่มเพื่อนทันที'), findsOneWidget);
      },
    );

    testWidgets('FriendsScreen renders friend list with items and nickname badges', (tester) async {
      final mockFriends = [
        FriendItemModel(
          friendshipId: 'f1',
          friendsSince: DateTime(2026, 1, 1),
          user: const FriendUserModel(
            id: 'u1',
            userCode: 'USR-111',
            displayName: 'Somchai Demo',
          ),
        ),
        FriendItemModel(
          friendshipId: 'f2',
          friendsSince: DateTime(2026, 1, 2),
          user: const FriendUserModel(
            id: 'u2',
            userCode: 'USR-222',
            displayName: 'ntdotjsx',
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            friendsListProvider.overrideWith((ref) async => mockFriends),
            incomingFriendRequestsProvider.overrideWith((ref) async => []),
            outgoingFriendRequestsProvider.overrideWith((ref) async => []),
            friendNicknameProvider.overrideWith(
              (ref) => FriendNicknameNotifier()..state = {'u2': 'ป่น'},
            ),
          ],
          child: MaterialApp(
            theme: LightTheme.theme,
            home: const FriendsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // For u1 (no nickname): shows displayName and 'ตั้งชื่อเล่น' action
      expect(find.text('Somchai Demo'), findsOneWidget);
      expect(find.text('ตั้งชื่อเล่น'), findsOneWidget);
      expect(find.text('รหัส: USR-111'), findsOneWidget);

      // For u2 (with nickname 'ป่น'): shows nickname 'ป่น', badge 'ชื่อเล่น', and real name 'ชื่อในระบบ: ntdotjsx'
      expect(find.text('ป่น'), findsOneWidget);
      expect(find.text('ชื่อเล่น'), findsOneWidget);
      expect(find.text('ชื่อในระบบ: ntdotjsx'), findsOneWidget);
      expect(find.text('รหัส: USR-222'), findsOneWidget);

      // Tap 'ตั้งชื่อเล่น' to open quick dialog
      await tester.tap(find.text('ตั้งชื่อเล่น'));
      await tester.pumpAndSettle();

      expect(find.text('ตั้งชื่อเล่นให้เพื่อน'), findsOneWidget);
      expect(find.text('บันทึก'), findsOneWidget);
    });

    testWidgets(
      'AddFriendScreen renders search input and validation elements',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: LightTheme.theme,
              home: const AddFriendScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('เพิ่มเพื่อนใหม่'), findsOneWidget);
        expect(
          find.text('ค้นหาด้วยรหัสประจำตัว (User Code / ID)'),
          findsOneWidget,
        );
        expect(find.text('ค้นหา'), findsOneWidget);
      },
    );
  });
}
