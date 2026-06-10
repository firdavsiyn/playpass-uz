import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/l10n/app_locale.dart';
import '../core/utils/plural.dart';

class Subscription {
  final String id;
  final String userId;
  final String plan; // 'basic' | 'standard' | 'pro' | 'vip'
  final DateTime startDate;
  final DateTime endDate;
  final int? hoursBalance; // null for unlimited (pro/vip)
  final int? hoursTotal; // null for unlimited (pro/vip)
  final int visitsToday;
  final String status; // 'active' | 'frozen' | 'expired' | 'suspended'
  final int priceUzs;
  final DateTime? frozenSince;
  final int frozenDaysUsed;

  /// Часы, перенесённые с прошлой подписки (rollover-бонус).
  /// Включены в hoursTotal и hoursBalance, но отображаются отдельно
  /// для коммуникации «вы получили бонус».
  final int hoursRolledOver;

  const Subscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.startDate,
    required this.endDate,
    this.hoursBalance,
    this.hoursTotal,
    this.visitsToday = 0,
    required this.status,
    required this.priceUzs,
    this.frozenSince,
    this.frozenDaysUsed = 0,
    this.hoursRolledOver = 0,
  });

  PlanConfig? get planConfig => AppConstants.plans[plan];
  bool get isUnlimited => planConfig?.isUnlimited ?? false;
  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());
  bool get isFrozen => status == 'frozen';
  bool get hasHours =>
      isUnlimited || (hoursBalance != null && hoursBalance! > 0);

  int get daysRemaining =>
      endDate.difference(DateTime.now()).inDays.clamp(0, 999);
  int get freezeDaysLeft => AppConstants.freezeMaxDaysPerMonth - frozenDaysUsed;
  bool get canFreeze => isActive && freezeDaysLeft > 0;

  String get planName => switch (plan) {
        'daily' => 'Day Pass',
        'day' => 'Day',
        'anytime' => 'Anytime',
        'basic' => 'Базовый',
        'standard' => 'Стандарт',
        'pro' => 'Про',
        'vip' => 'VIP',
        _ => plan,
      };

  /// Balance shown on the card: number of visits left, or ∞ for unlimited.
  String get hoursText {
    if (isUnlimited) return '∞';
    return '${hoursBalance ?? 0}';
  }

  /// Alias with the correct unit name (preferred going forward).
  String get visitsDisplay => hoursText;

  String get hoursSubtext {
    if (isUnlimited) return 'Безлимит · 1 визит/день';
    return 'из ${pluralVisits(hoursTotal ?? 0)}';
  }

  /// Localized version of hoursSubtext using ref.lang()
  String localizedHoursSubtext(WidgetRef ref) {
    if (isUnlimited) return ref.lang('sub.unlimited_label');
    return ref.lang('sub.of_visits').replaceAll('{n}', '${hoursTotal ?? 0}');
  }

  /// Localized plan name using ref.lang()
  String localizedPlanName(WidgetRef ref) => switch (plan) {
        'daily' => 'Day Pass',
        'day' => 'Day',
        'anytime' => 'Anytime',
        'basic' => ref.lang('plan.basic'),
        'standard' => ref.lang('plan.standard'),
        'pro' => ref.lang('plan.pro'),
        'vip' => ref.lang('plan.vip'),
        _ => plan,
      };

  double get hoursProgress {
    if (isUnlimited) return 1.0;
    if (hoursTotal == null || hoursTotal! <= 0) return 0;
    return ((hoursBalance ?? 0) / hoursTotal!).clamp(0.0, 1.0);
  }

  /// Проверяет доступ к зоне в текущий таймслот
  bool canAccessZone(String zoneType) {
    final timeSlot = AppConstants.getCurrentTimeSlot();
    return AppConstants.checkAccess(plan, zoneType, timeSlot);
  }

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        plan: json['plan'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        hoursBalance: json['hours_balance'] as int?,
        hoursTotal: json['hours_total'] as int?,
        visitsToday: json['visits_today'] as int? ?? 0,
        status: json['status'] as String,
        priceUzs: json['price_uzs'] as int? ?? 0,
        frozenSince: json['frozen_since'] != null
            ? DateTime.parse(json['frozen_since'] as String)
            : null,
        frozenDaysUsed: json['frozen_days_used'] as int? ?? 0,
        hoursRolledOver: json['hours_rolled_over'] as int? ?? 0,
      );
}
