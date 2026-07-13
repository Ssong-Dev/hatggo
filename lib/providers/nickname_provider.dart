import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _nicknamePrefKey = 'user_nickname';

class NicknameNotifier extends Notifier<String> {
  @override
  String build() {
    _loadFromPrefs();
    // Default initial nickname while loading
    return '익명_새싹';
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_nicknamePrefKey);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved;
    } else {
      // 닉네임이 없으면 난수를 발생시켜 기본 닉네임 부여
      final randomNum = Random().nextInt(9000) + 1000;
      final defaultNickname = '익명_$randomNum';
      state = defaultNickname;
      await prefs.setString(_nicknamePrefKey, defaultNickname);
    }
  }

  Future<void> updateNickname(String newNickname) async {
    if (newNickname.trim().isEmpty) return;
    state = newNickname.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknamePrefKey, state);
  }
}

final nicknameProvider = NotifierProvider<NicknameNotifier, String>(() {
  return NicknameNotifier();
});
