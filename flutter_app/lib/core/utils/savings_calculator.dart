/// Calculates subscription savings in the VISITS-based model.
///
/// A "visit" is one club session. The saving is the cash a member would
/// have paid per session at the door, minus what the subscription cost.
/// Per-visit cash values approximate an average paid session by zone:
/// - VIP zones: ~45,000 UZS/visit
/// - Pro (premium PC): ~35,000 UZS/visit
/// - Standard / Day / Anytime: ~30,000 UZS/visit
/// - Basic / Day-Pass: ~25,000 UZS/visit
class SavingsCalculator {
  /// Cash value of one club visit (session) by plan.
  static const Map<String, int> sessionValueByPlan = {
    'vip': 45000,
    'pro': 35000,
    'anytime': 30000,
    'day': 30000,
    'standard': 30000,
    'daily': 25000,
    'basic': 25000,
  };

  /// Average cash value of a single visit when the plan is unknown.
  static const int avgCashSession = 30000;

  /// Returns the per-visit cash value for a given plan.
  /// (Method name kept for backward compatibility with callers.)
  static int rateForPlan(String plan) =>
      sessionValueByPlan[plan] ?? avgCashSession;

  /// Calculates savings: (visits × per-visit cash value) − subscriptionCost.
  /// Returns 0 if savings are negative.
  /// NOTE: [hoursUsed] now means VISITS used (the balance counts visits).
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
