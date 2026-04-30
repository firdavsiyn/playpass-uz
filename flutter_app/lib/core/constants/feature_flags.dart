/// Feature flags for gradual rollout.
///
/// Set a flag to `false` to hide the feature everywhere in the app
/// (home screen quick actions, profile menu items, deep-link routes, etc.).
///
/// As features become production-ready, flip flags to `true` and re-deploy.
class FeatureFlags {
  // ── Gaming features ──────────────────────────────────────────
  static const bool tournaments = false;
  static const bool lfg = false;            // Looking-For-Group / Тиммейты
  static const bool leaderboard = false;
  static const bool playerStats = false;    // XP / профили игроков
  static const bool achievements = false;

  // ── Content & engagement ─────────────────────────────────────
  static const bool stories = false;        // Новости
  static const bool happyHours = false;     // Скидки / акции по часам
  static const bool loyalty = false;        // Программа лояльности

  // ── Map & discovery ──────────────────────────────────────────
  /// Standalone fullscreen map button on home (карта).
  /// The clubs tab still has its inline map view — this flag only
  /// controls the quick-action shortcut.
  static const bool fullscreenMapShortcut = false;

  // ── Booking ──────────────────────────────────────────────────
  static const bool booking = false;        // Бронирование ПК

  // ── Other ────────────────────────────────────────────────────
  static const bool gifts = true;           // Подарочные сертификаты — оставляем
  static const bool referral = true;        // Реферальная программа — оставляем
  static const bool freeze = true;          // Заморозка подписки — оставляем
  static const bool savings = true;         // Виджет «Сколько сэкономили» — оставляем
  static const bool friends = true;         // Sprint 3: Friend system
  static const bool smartHomeFeed = true;   // Sprint 3: Personalized hints
}
