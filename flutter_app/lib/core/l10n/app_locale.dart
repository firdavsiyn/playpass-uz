import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'strings_ru.dart';
import 'strings_uz.dart';

/// Current app locale: 'ru' or 'uz'
final localeProvider = StateProvider<String>((ref) => 'ru');

/// Returns the translated string map for the current locale
Map<String, String> tr(String locale) => locale == 'uz' ? stringsUz : stringsRu;

/// Extension for easy access in widgets
extension LocaleRef on WidgetRef {
  Map<String, String> get t => tr(watch(localeProvider));
  String lang(String key) => t[key] ?? key;
}
