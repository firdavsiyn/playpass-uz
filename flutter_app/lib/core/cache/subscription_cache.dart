import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/subscription.dart';

/// Local stale-while-revalidate cache for the user's current subscription.
///
/// Purpose: on a cold app start we don't want the home screen to be empty
/// for the 200–800 ms it takes Supabase to return the user's plan. We
/// persist the raw JSON of the last successful query, replay it instantly
/// when the app reopens, and overwrite with fresh data as soon as the
/// network call completes.
class SubscriptionCache {
  static const _key = 'home_cache.active_subscription.v1';

  /// Read the last-known subscription from disk. Returns null if there's
  /// no cache yet or if the stored JSON is corrupted (e.g. model change).
  static Future<Subscription?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Subscription.fromJson(map);
    } catch (_) {
      // Corrupted cache (schema drift) — wipe and return null.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
      } catch (_) {}
      return null;
    }
  }

  /// Persist the raw Supabase response. Called by SupabaseService right
  /// after a successful fetch.
  static Future<void> writeRaw(Map<String, dynamic> raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(raw));
    } catch (_) {
      // Cache is best-effort; never propagate IO errors to callers.
    }
  }

  /// Clear cache — call on logout or when the server returns "no active sub".
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
