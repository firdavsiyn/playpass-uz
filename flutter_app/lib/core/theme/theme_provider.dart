import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode: 'dark' or 'light'
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, String>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<String> {
  bool _loaded = false;

  ThemeModeNotifier() : super('dark') {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_mode');
      if (saved != null && !_loaded) {
        state = saved;
      }
    } catch (e) {
      debugPrint('Theme load error: $e');
    } finally {
      _loaded = true;
    }
  }

  Future<void> toggle() async {
    state = state == 'dark' ? 'light' : 'dark';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', state);
  }

  bool get isDark => state == 'dark';
}
