/// Calculates subscription savings based on plan-specific hourly rates.
///
/// Rates are approximations of average club prices per zone:
/// - VIP zones: ~45,000 UZS/hr
/// - Pro (premium PC): ~35,000 UZS/hr
/// - Standard (regular PC): ~25,000 UZS/hr
/// - Basic (budget): ~18,000 UZS/hr
class SavingsCalculator {
  static const Map<String, int> hourlyRatesByPlan = {
    'vip': 45000,
    'pro': 35000,
    'standard': 25000,
    'basic': 18000,
  };

  /// Default rate when plan is unknown
  static const int defaultHourlyRate = 25000;

  /// Returns hourly rate for a given plan name
  static int rateForPlan(String plan) =>
      hourlyRatesByPlan[plan] ?? defaultHourlyRate;

  /// Calculates savings: (hours × rate) − subscriptionCost
  /// Returns 0 if savings are negative.
  static int calculate({
    required int hoursUsed,
    required String plan,
    required int subscriptionCost,
  }) {
    final regularCost = hoursUsed * rateForPlan(plan);
    final saved = regularCost - subscriptionCost;
    return saved > 0 ? saved : 0;
  }

  /// Formats amount with thousand separators: 301500 → "301 500"
  /// Uses non-breaking space so the number doesn't wrap.
  static String formatAmount(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
