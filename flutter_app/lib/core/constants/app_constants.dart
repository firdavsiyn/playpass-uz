// ignore_for_file: constant_identifier_names
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
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs',
  );

  // API endpoints
  static const String checkinEndpoint = '/functions/v1/checkin';
  static const String qrValidateEndpoint = '/functions/v1/qr-validate';

  // Business rules
  static const int checkinCooldownMinutes = 30;
  static const int maxDailyCheckins = 8;
  static const int checkinRadiusMeters = 500;
  static const int freezeMaxDaysPerMonth = 5;
  static const int referralBonusHours = 3;

  // ── 3 тайм-слота ───────────────────────────────────────────
  static const String slotDay = 'day';         // 08:00–20:00
  static const String slotEvening = 'evening'; // 20:00–00:00
  static const String slotNight = 'night';     // 00:00–08:00

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

  // ── 4 тарифа (полная система v1.0) ─────────────────────────
  static const Map<String, PlanConfig> plans = {
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

  static String levelIcon(String level) => switch (level) {
    'novice' => '🎮',
    'gamer' => '💙',
    'pro' => '⚡',
    'legend' => '👑',
    _ => '🎮',
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
