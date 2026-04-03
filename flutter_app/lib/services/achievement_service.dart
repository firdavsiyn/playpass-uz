import 'supabase_service.dart';

class AchievementService {
  final _svc = SupabaseService();

  /// Check and unlock achievements after key events
  Future<List<String>> checkAndUnlock() async {
    final userId = _svc.currentUser?.id;
    if (userId == null) return [];

    // Get already unlocked
    final userAch = await _svc.getUserAchievements();
    final unlocked = userAch.map((e) => e['achievement_id'] as String).toSet();

    // Get all achievements
    final all = await _svc.getAllAchievements();
    final newlyUnlocked = <String>[];

    // Get stats
    final stats = await _svc.getAllTimeVisitStats();
    final totalVisits = stats['total_visits'] as int? ?? 0;

    // Count unique clubs
    final visits = await _svc.getVisitHistory();
    final uniqueClubs = visits.map((v) => v.clubId).toSet().length;

    // Count night visits (00-08)
    final nightVisits = visits.where((v) => v.createdAt.hour < 8).length;

    // Count weekend visits
    final weekendVisits = visits.where((v) =>
        v.createdAt.weekday == DateTime.saturday ||
        v.createdAt.weekday == DateTime.sunday).length;

    // Favorites count
    final favIds = await _svc.getFavoriteClubIds();

    // Referral count
    final refStats = await _svc.getReferralStats();
    final friendsCount = refStats['friends_count'] as int? ?? 0;

    // Check each achievement
    for (final a in all) {
      final id = a['id'] as String;
      if (unlocked.contains(id)) continue;

      final threshold = a['threshold'] as int? ?? 1;
      bool earned = false;

      switch (id) {
        case 'first_visit':
          earned = totalVisits >= threshold;
        case 'five_visits':
          earned = totalVisits >= threshold;
        case 'ten_visits':
          earned = totalVisits >= threshold;
        case 'twenty_five_visits':
          earned = totalVisits >= threshold;
        case 'ten_clubs':
          earned = uniqueClubs >= threshold;
        case 'night_gamer':
          earned = nightVisits >= threshold;
        case 'weekend_warrior':
          earned = weekendVisits >= threshold;
        case 'social_butterfly':
          earned = friendsCount >= threshold;
        case 'favorite_collector':
          earned = favIds.length >= threshold;
        // reviewer is checked separately
      }

      if (earned) {
        try {
          await _svc.unlockAchievement(id);
          newlyUnlocked.add(a['name_ru'] as String? ?? id);
        } catch (_) {}
      }
    }

    return newlyUnlocked;
  }
}
