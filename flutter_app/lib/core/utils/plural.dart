/// Russian pluralization helpers for the visits-based subscription model.
///
/// RU rules: 1 визит · 2-4 визита · 5-20 визитов (with the usual %10/%100
/// exceptions for the teens).
String pluralVisits(int n) {
  final m10 = n % 10;
  final m100 = n % 100;
  if (m10 == 1 && m100 != 11) return '$n визит';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return '$n визита';
  return '$n визитов';
}

/// Just the word form without the number — for «осталось: <word>» layouts.
String visitsWord(int n) {
  final m10 = n % 10;
  final m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'визит';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'визита';
  return 'визитов';
}

/// Uzbek — no plural agreement.
String pluralVisitsUz(int n) => '$n tashrif';
