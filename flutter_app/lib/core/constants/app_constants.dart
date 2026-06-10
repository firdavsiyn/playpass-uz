// ignore_for_file: constant_identifier_names
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_locale.dart';

class AppConstants {
  // App name
  static const String appName = 'PlayPass';

  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rizyqzjszaknzjboooow.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs',
  );

  /// Sentry DSN for error tracking. Empty = Sentry disabled.
  /// Set via --dart-define=SENTRY_DSN=https://...@sentry.io/... at build time.
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  /// App version for release tracking in Sentry
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// Environment: 'production', 'staging', or 'development'
  static const String environment =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

  // API endpoints
  static const String checkinEndpoint = '/functions/v1/checkin';
  static const String qrValidateEndpoint = '/functions/v1/qr-validate';

  // Business rules
  static const int checkinCooldownMinutes = 30;
  static const int maxDailyCheckins = 8;
  static const int checkinRadiusMeters = 500;
  static const int freezeMaxDaysPerMonth = 5;

  /// Сколько часов получает приглашающий за каждого друга по реф. ссылке.
  /// Boost-режим (10ч) активен на soft-launch, потом снизим до 5ч.
  static const int referralBonusHours = 10;

  // ── 3 тайм-слота ───────────────────────────────────────────
  static const String slotDay = 'day'; // 08:00–20:00
  static const String slotEvening = 'evening'; // 20:00–00:00
  static const String slotNight = 'night'; // 00:00–08:00

  static String getCurrentTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour >= 8 && hour < 20) return slotDay;
    if (hour >= 20) return slotEvening;
    return slotNight;
  }

  static String timeSlotLabel(String slot) => switch (slot) {
        'day' => 'День (08–20)',
        'evening' => 'Вечер (20–00)',
        'night' => 'Ночь (00–08)',
        _ => slot,
      };

  // ── 3 типа зон ─────────────────────────────────────────────
  static const String zoneBasic = 'basic';
  static const String zonePro = 'pro';
  static const String zoneVip = 'vip';

  static String zoneLabel(String type) => switch (type) {
        'basic' => 'Базовая',
        'pro' => 'Про',
        'vip' => 'VIP',
        _ => type,
      };

  /// Коды тарифов, доступных к ПОКУПКЕ (показываются в продаже).
  /// Остальные коды в [plans] — legacy, нужны только чтобы корректно
  /// отрисовать уже существующие подписки (например plan='vip').
  static const List<String> purchasablePlanCodes = ['daily', 'day', 'anytime'];

  // ── Тарифы ─────────────────────────────────────────────────
  // ВАЖНО: поле hours теперь трактуется как ВИЗИТЫ/мес (BM v1.2).
  static const Map<String, PlanConfig> plans = {
    // Day-Pass — пробный вход: 4 визита, действует 1 день
    'daily': PlanConfig(
      id: 'daily',
      name: 'Day Pass',
      hours: 4,
      isUnlimited: false,
      priceUzs: 25000,
      description: '4 визита на 1 день, Базовая зона',
      allowedZones: ['basic'],
      allowedSlots: ['day', 'evening', 'night'],
    ),
    // Day — основной off-peak тариф: 12 визитов, только день 08–18
    'day': PlanConfig(
      id: 'day',
      name: 'Day',
      hours: 12,
      isUnlimited: false,
      priceUzs: 149000,
      description: '12 визитов/мес, день 08–18, Базовая + Про зона',
      allowedZones: ['basic', 'pro'],
      allowedSlots: ['day'],
    ),
    // Anytime — круглосуточный: 12 визитов в любое время
    'anytime': PlanConfig(
      id: 'anytime',
      name: 'Anytime',
      hours: 12,
      isUnlimited: false,
      priceUzs: 249000,
      description: '12 визитов/мес, круглосуточно, Базовая + Про зона',
      allowedZones: ['basic', 'pro'],
      allowedSlots: ['day', 'evening', 'night'],
    ),
    // ── LEGACY (не продаются, оставлены для отрисовки старых подписок) ──
    'basic': PlanConfig(
      id: 'basic',
      name: 'Базовый',
      hours: 15,
      isUnlimited: false,
      priceUzs: 149000,
      description: '15 часов/мес, Базовая зона, день (08–20)',
      allowedZones: ['basic'],
      allowedSlots: ['day'],
    ),
    'standard': PlanConfig(
      id: 'standard',
      name: 'Стандарт',
      hours: 30,
      isUnlimited: false,
      priceUzs: 229000,
      description: '30 часов/мес, Базовая + Про зона, круглосуточно',
      allowedZones: ['basic', 'pro'],
      allowedSlots: ['day', 'evening', 'night'],
    ),
    'pro': PlanConfig(
      id: 'pro',
      name: 'Про',
      hours: 0,
      isUnlimited: true,
      priceUzs: 399000,
      description: '1 визит/день, Базовая + Про зона, круглосуточно',
      allowedZones: ['basic', 'pro'],
      allowedSlots: ['day', 'evening', 'night'],
    ),
    'vip': PlanConfig(
      id: 'vip',
      name: 'VIP',
      hours: 0,
      isUnlimited: true,
      priceUzs: 599000,
      description: '1 визит/день, Все зоны включая VIP, круглосуточно',
      allowedZones: ['basic', 'pro', 'vip'],
      allowedSlots: ['day', 'evening', 'night'],
    ),
    // ── Годовые тарифы (−30% к месячной цене × 12) ──────────
    'standard_annual': PlanConfig(
      id: 'standard_annual',
      name: 'Стандарт · год',
      hours: 30,
      isUnlimited: false,
      priceUzs: 1250000,
      description: 'Стандарт на 12 месяцев, выгода ~30%',
      allowedZones: ['basic', 'pro'],
      allowedSlots: ['day', 'evening', 'night'],
    ),
    'vip_annual': PlanConfig(
      id: 'vip_annual',
      name: 'VIP · год',
      hours: 0,
      isUnlimited: true,
      priceUzs: 2500000,
      description: 'VIP-безлимит на 12 месяцев, выгода ~30%',
      allowedZones: ['basic', 'pro', 'vip'],
      allowedSlots: ['day', 'evening', 'night'],
    ),
  };

  /// Проверяет доступ по матрице: plan × zone × timeSlot
  static bool checkAccess(String plan, String zoneType, String timeSlot) {
    final config = plans[plan];
    if (config == null) return false;
    return config.allowedZones.contains(zoneType) &&
        config.allowedSlots.contains(timeSlot);
  }

  // Payout rates
  static const double clubRevenueShare = 0.70;

  // Deep link scheme
  static const String deepLinkScheme = 'playpassuz';
  static const String checkinPath = 'checkin';

  // ── Ручная оплата (v1.0 — заглушка, платёж в v1.1) ────────
  static const String paymentPaymePhone = '+998 XX XXX XX XX';
  static const String paymentCardNumber = '8600 XXXX XXXX XXXX';
  static const String paymentCardHolder = 'PlayPass';

  // ── Уровни активности ──────────────────────────────────────
  static String levelFromHours(int hoursThisMonth) {
    if (hoursThisMonth >= 30) return 'legend';
    if (hoursThisMonth >= 16) return 'pro';
    if (hoursThisMonth >= 6) return 'gamer';
    return 'novice';
  }

  static String levelLabel(String level) => switch (level) {
        'novice' => 'Новичок',
        'gamer' => 'Геймер',
        'pro' => 'Про',
        'legend' => 'Легенда',
        _ => level,
      };

  /// Locale-aware level label
  static String localizedLevelLabel(String level, WidgetRef ref) =>
      switch (level) {
        'novice' => ref.lang('level.novice'),
        'gamer' => ref.lang('level.gamer'),
        'pro' => ref.lang('level.pro'),
        'legend' => ref.lang('level.legend'),
        _ => level,
      };

  /// Locale-aware zone label
  static String localizedZoneLabel(String type, WidgetRef ref) =>
      switch (type) {
        'basic' => ref.lang('zone.basic'),
        'pro' => ref.lang('zone.pro'),
        'vip' => ref.lang('zone.vip'),
        _ => type,
      };

  /// Locale-aware time slot label
  static String localizedTimeSlotLabel(String slot, WidgetRef ref) =>
      switch (slot) {
        'day' => ref.lang('slot.day'),
        'evening' => ref.lang('slot.evening'),
        'night' => ref.lang('slot.night'),
        _ => slot,
      };

  static String levelIcon(String level) => switch (level) {
        'novice' => '',
        'gamer' => '',
        'pro' => '',
        'legend' => '',
        _ => '',
      };
}

class PlanConfig {
  final String id;
  final String name;
  final int hours; // 0 for unlimited
  final bool isUnlimited;
  final int priceUzs;
  final String description;
  final List<String> allowedZones;
  final List<String> allowedSlots;

  const PlanConfig({
    required this.id,
    required this.name,
    required this.hours,
    required this.isUnlimited,
    required this.priceUzs,
    required this.description,
    required this.allowedZones,
    required this.allowedSlots,
  });
}
