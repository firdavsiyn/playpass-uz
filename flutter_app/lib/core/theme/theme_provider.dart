import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode: 'dark' or 'light'
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, String>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<String> {
  ThemeModeNotifier() : super('dark') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('theme_mode') ?? 'dark';
  }

  Future<void> toggle() async {
    state = state == 'dark' ? 'light' : 'dark';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', state);
  }

  bool get isDark => state == 'dark';
}
