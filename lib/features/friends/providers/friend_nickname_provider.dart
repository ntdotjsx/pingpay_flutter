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
        final idOrCode = key.substring(_prefix.length);
        final value = prefs.getString(key);
        if (value != null && value.trim().isNotEmpty) {
          map[idOrCode] = value.trim();
        }
      }
      state = map;
    } catch (_) {}
  }

  String getEffectiveName({
    String? userId,
    String? userCode,
    required String defaultName,
  }) {
    if (userId != null && userId.isNotEmpty && state.containsKey(userId)) {
      final nick = state[userId];
      if (nick != null && nick.trim().isNotEmpty) return nick.trim();
    }
    if (userCode != null && userCode.isNotEmpty && state.containsKey(userCode)) {
      final nick = state[userCode];
      if (nick != null && nick.trim().isNotEmpty) return nick.trim();
    }
    return defaultName;
  }

  String? getNickname({String? userId, String? userCode}) {
    if (userId != null && userId.isNotEmpty && state.containsKey(userId)) {
      return state[userId];
    }
    if (userCode != null && userCode.isNotEmpty && state.containsKey(userCode)) {
      return state[userCode];
    }
    return null;
  }

  Future<void> setNickname({
    String? userId,
    String? userCode,
    required String nickname,
  }) async {
    final clean = nickname.trim();
    final prefs = await SharedPreferences.getInstance();
    final updated = Map<String, String>.from(state);

    final keysToUpdate = <String>[];
    if (userId != null && userId.isNotEmpty) keysToUpdate.add(userId);
    if (userCode != null && userCode.isNotEmpty) keysToUpdate.add(userCode);

    if (clean.isEmpty) {
      for (final key in keysToUpdate) {
        await prefs.remove('$_prefix$key');
        updated.remove(key);
      }
    } else {
      for (final key in keysToUpdate) {
        await prefs.setString('$_prefix$key', clean);
        updated[key] = clean;
      }
    }
    state = updated;
  }

  Future<void> removeNickname({String? userId, String? userCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Map<String, String>.from(state);

    final keysToRemove = <String>[];
    if (userId != null && userId.isNotEmpty) keysToRemove.add(userId);
    if (userCode != null && userCode.isNotEmpty) keysToRemove.add(userCode);

    for (final key in keysToRemove) {
      await prefs.remove('$_prefix$key');
      updated.remove(key);
    }
    state = updated;
  }
}

final friendNicknameProvider =
    StateNotifierProvider<FriendNicknameNotifier, Map<String, String>>(
  (ref) => FriendNicknameNotifier(),
);
