import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendNicknameNotifier extends StateNotifier<Map<String, String>> {
  FriendNicknameNotifier() : super({}) {
    _loadNicknames();
  }

  static const String _prefix = 'pingpay_friend_nickname_';

  Future<void> _loadNicknames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      final Map<String, String> map = {};
      for (final key in keys) {
        final userId = key.substring(_prefix.length);
        final value = prefs.getString(key);
        if (value != null && value.trim().isNotEmpty) {
          map[userId] = value.trim();
        }
      }
      state = map;
    } catch (_) {}
  }

  String getEffectiveName({
    required String userId,
    required String defaultName,
  }) {
    final nick = state[userId];
    if (nick != null && nick.trim().isNotEmpty) {
      return nick.trim();
    }
    return defaultName;
  }

  String? getNickname(String userId) {
    return state[userId];
  }

  Future<void> setNickname({
    required String userId,
    required String nickname,
  }) async {
    final clean = nickname.trim();
    final prefs = await SharedPreferences.getInstance();
    if (clean.isEmpty) {
      await prefs.remove('$_prefix$userId');
      final updated = Map<String, String>.from(state)..remove(userId);
      state = updated;
    } else {
      await prefs.setString('$_prefix$userId', clean);
      final updated = Map<String, String>.from(state)..[userId] = clean;
      state = updated;
    }
  }

  Future<void> removeNickname(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$userId');
    final updated = Map<String, String>.from(state)..remove(userId);
    state = updated;
  }
}

final friendNicknameProvider =
    StateNotifierProvider<FriendNicknameNotifier, Map<String, String>>(
  (ref) => FriendNicknameNotifier(),
);
