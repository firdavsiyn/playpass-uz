import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode: 'dark', 'light', or 'auto'
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

  String get effectiveTheme {
    if (state == 'auto') {
      final hour = DateTime.now().hour;
      return (hour >= 7 && hour < 20) ? 'light' : 'dark';
    }
    return state;
  }

  bool get isDark => effectiveTheme == 'dark';

  Future<void> toggle() async {
    if (state == 'dark') {
      state = 'light';
    } else if (state == 'light') {
      state = 'auto';
    } else {
      state = 'dark';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', state);
  }

  Future<void> setMode(String mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', state);
  }
}
