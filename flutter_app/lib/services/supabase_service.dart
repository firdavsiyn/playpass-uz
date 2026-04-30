import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../models/subscription_request.dart';
import '../models/club.dart';
import '../models/club_zone.dart';
import '../models/visit.dart';
import '../models/review.dart';
import '../models/tournament.dart';
import '../models/story.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // ── Auth ──────────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Safe accessor — throws a clear message instead of null-pointer crash.
  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.id;
  }

  // ── Users ─────────────────────────────────────────────────
  Future<void> updateUserProfile(
      {required String name, String? avatarUrl}) async {
    final userId = _userId;
    await _client.from('users').update({
      'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', userId);
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final res =
        await _client.from('users').select().eq('id', userId).maybeSingle();
    return res;
  }

  /// Grant the one-time welcome bonus (1 free hour, 24h validity).
  /// Returns null if successful, or a reason string if already claimed.
  Future<String?> grantWelcomeBonus() async {
    try {
      final res = await _client.rpc('grant_welcome_bonus');
      if (res is Map && res['success'] == false)
        return res['reason'] as String?;
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Friend system ─────────────────────────────────────────

  /// Send a friend request using the friend's referral code as identifier.
  /// Returns null on success or a reason string ('user_not_found',
  /// 'cannot_self', 'already_exists').
  Future<String?> sendFriendRequest(String friendCode) async {
    try {
      final res = await _client
          .rpc('send_friend_request', params: {'p_friend_code': friendCode});
      if (res is Map && res['success'] == false)
        return res['reason'] as String?;
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Accept a pending friend request
  Future<String?> acceptFriendRequest(String friendshipId) async {
    try {
      final res = await _client.rpc('accept_friend_request',
          params: {'p_friendship_id': friendshipId});
      if (res is Map && res['success'] == false)
        return res['reason'] as String?;
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Decline / remove a friendship
  Future<void> removeFriendship(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  /// Get all friends + their current online status (in active session)
  Future<List<Map<String, dynamic>>> getFriendsWithStatus() async {
    try {
      final res = await _client.rpc('get_friends_with_status');
      if (res is List) return res.cast<Map<String, dynamic>>();
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get personalized home recommendation cards. Returns 0-4 cards.
  Future<List<Map<String, dynamic>>> getHomeRecommendations() async {
    try {
      final res = await _client.rpc('get_home_recommendations');
      if (res is List) {
        return res.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check if the user has already claimed the welcome bonus
  Future<bool> hasClaimedWelcomeBonus() async {
    final userId = _userId;
    final res = await _client
        .from('users')
        .select('welcome_bonus_at')
        .eq('id', userId)
        .maybeSingle();
    return res != null && res['welcome_bonus_at'] != null;
  }

  // ── Subscriptions ─────────────────────────────────────────
  Future<Subscription?> getActiveSubscription() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final res = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .inFilter('status', ['active', 'frozen'])
        .gte('end_date', today)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return Subscription.fromJson(res);
  }

  // ── Freeze / Unfreeze (calendar-based, 5 days/month) ─────
  /// Get freeze dates for a subscription in a given month
  Future<List<DateTime>> getFreezeDates(String subscriptionId,
      {int? year, int? month}) async {
    final userId = _userId;
    final y = year ?? DateTime.now().year;
    final m = month ?? DateTime.now().month;
    final from = '$y-${m.toString().padLeft(2, '0')}-01';
    final to = DateTime(y, m + 1, 0); // last day of month
    final toStr =
        '$y-${m.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';

    final res = await _client
        .from('subscription_freezes')
        .select('freeze_date')
        .eq('subscription_id', subscriptionId)
        .eq('user_id', userId)
        .gte('freeze_date', from)
        .lte('freeze_date', toStr)
        .order('freeze_date');
    return (res as List)
        .map((r) => DateTime.parse(r['freeze_date'] as String))
        .toList();
  }

  /// Count freeze days used this month
  Future<int> getFreezeDaysUsedThisMonth(String subscriptionId) async {
    final dates = await getFreezeDates(subscriptionId);
    return dates.length;
  }

  /// Toggle a freeze date (add or remove)
  Future<bool> toggleFreezeDate(String subscriptionId, DateTime date) async {
    try {
      final userId = _userId;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Check if already exists
      final existing = await _client
          .from('subscription_freezes')
          .select('id')
          .eq('subscription_id', subscriptionId)
          .eq('freeze_date', dateStr)
          .maybeSingle();

      if (existing != null) {
        // Remove freeze
        await _client
            .from('subscription_freezes')
            .delete()
            .eq('id', existing['id'] as String);
        // Shrink end_date by 1 day
        final sub = await _client
            .from('subscriptions')
            .select('end_date')
            .eq('id', subscriptionId)
            .single();
        final oldEnd = DateTime.parse(sub['end_date'] as String);
        await _client
            .from('subscriptions')
            .update({
              'end_date': oldEnd
                  .subtract(const Duration(days: 1))
                  .toIso8601String()
                  .split('T')[0],
            })
            .eq('id', subscriptionId)
            .eq('user_id', userId);
        return false; // removed
      } else {
        // Add freeze
        await _client.from('subscription_freezes').insert({
          'subscription_id': subscriptionId,
          'user_id': userId,
          'freeze_date': dateStr,
        });
        // Extend end_date by 1 day
        final sub = await _client
            .from('subscriptions')
            .select('end_date')
            .eq('id', subscriptionId)
            .single();
        final oldEnd = DateTime.parse(sub['end_date'] as String);
        await _client
            .from('subscriptions')
            .update({
              'end_date': oldEnd
                  .add(const Duration(days: 1))
                  .toIso8601String()
                  .split('T')[0],
            })
            .eq('id', subscriptionId)
            .eq('user_id', userId);
        return true; // added
      }
    } on PostgrestException catch (e) {
      throw Exception('Freeze toggle failed: ${e.message}');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Freeze toggle failed: $e');
    }
  }

  // Legacy freeze methods kept for backward compat
  Future<void> freezeSubscription(String subscriptionId, int days) async {
    final userId = _userId;
    await _client
        .from('subscriptions')
        .update({
          'status': 'frozen',
          'frozen_since': DateTime.now().toIso8601String().split('T')[0],
        })
        .eq('id', subscriptionId)
        .eq('user_id', userId);
  }

  Future<void> unfreezeSubscription(String subscriptionId) async {
    final userId = _userId;
    await _client
        .from('subscriptions')
        .update({
          'status': 'active',
          'frozen_since': null,
        })
        .eq('id', subscriptionId)
        .eq('user_id', userId);
  }

  // ── Subscription Requests (ручная оплата) ─────────────────
  Future<void> createSubscriptionRequest({
    required String plan,
    required int amountUzs,
    required String userPhone,
    String? paymentNote,
  }) async {
    final userId = _userId;
    await _client.from('subscription_requests').insert({
      'user_id': userId,
      'plan': plan,
      'amount_uzs': amountUzs,
      'user_phone': userPhone,
      'payment_note': paymentNote,
    });
  }

  Future<List<SubscriptionRequest>> getMySubscriptionRequests() async {
    final userId = _userId;
    final res = await _client
        .from('subscription_requests')
        .select(
            'id, user_id, plan, amount_uzs, user_phone, payment_note, status, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => SubscriptionRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionRequest?> getPendingRequest() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final res = await _client
        .from('subscription_requests')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return SubscriptionRequest.fromJson(res);
  }

  // ── Clubs ─────────────────────────────────────────────────
  /// Get active clubs. Pass [limit] to bound the result (e.g. on home screen
  /// only top 15 are shown). Default returns all (used by full clubs list).
  Future<List<Club>> getActiveClubs({String? tier, int? limit}) async {
    var query = _client
        .from('clubs')
        .select(
            'id, name, address, lat, lon, photos, working_hours, pc_count, rating, status, tier, has_playstation, price_per_hour, review_count')
        .eq('status', 'active');

    if (tier != null) {
      query = query.eq('tier', tier);
    }

    final ordered = query.order('rating', ascending: false);
    final res = limit != null ? await ordered.limit(limit) : await ordered;
    return (res as List)
        .map((e) => Club.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Club?> getClub(String clubId) async {
    final res =
        await _client.from('clubs').select().eq('id', clubId).maybeSingle();
    if (res == null) return null;
    return Club.fromJson(res);
  }

  // ── Club Zones ────────────────────────────────────────────
  Future<List<ClubZone>> getClubZones(String clubId) async {
    final res = await _client
        .from('club_zones')
        .select('id, club_id, type, name, capacity, is_active')
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('type');
    return (res as List)
        .map((e) => ClubZone.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Visits ────────────────────────────────────────────────
  Future<List<Visit>> getVisitHistory({
    int? month,
    int? year,
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = _userId;
    var query = _client
        .from('visits')
        .select('id, user_id, club_id, hours_spent, created_at, clubs(name)')
        .eq('user_id', userId);

    if (month != null && year != null) {
      final from = DateTime(year, month, 1);
      final to = DateTime(year, month + 1, 0, 23, 59, 59);
      query = query
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());
    }

    final res = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (res as List)
        .map((e) => Visit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Checkin ───────────────────────────────────────────────
  Future<Map<String, dynamic>> checkin({
    required String zoneId,
    required String qrHmac,
    double? geoLat,
    double? geoLon,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'checkin',
        body: {
          'zone_id': zoneId,
          'qr_hmac': qrHmac,
          if (geoLat != null) 'geo_lat': geoLat,
          if (geoLon != null) 'geo_lon': geoLon,
        },
      );

      if (response.data == null) {
        throw Exception('Checkin failed: no response');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error'] as String);
      }

      return data;
    } on FunctionException catch (e) {
      throw Exception('Checkin failed: ${e.reasonPhrase ?? 'server error'}');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Checkin failed: $e');
    }
  }

  // ── Promo Codes ───────────────────────────────────────────
  Future<Map<String, dynamic>?> validatePromoCode(String code) async {
    final res = await _client
        .from('promos')
        .select()
        .eq('code', code.toUpperCase().trim())
        .eq('is_active', true)
        .maybeSingle();
    if (res == null) return null;

    // Check expiry
    final expiresAt = res['expires_at'] as String?;
    if (expiresAt != null &&
        DateTime.parse(expiresAt).isBefore(DateTime.now())) {
      return null;
    }

    // Check usage limit
    final maxUses = res['max_uses'] as int? ?? 0;
    final usedCount = res['used_count'] as int? ?? 0;
    if (maxUses > 0 && usedCount >= maxUses) return null;

    return res;
  }

  Future<Map<String, dynamic>> applyPromoCode(String code) async {
    final userId = _userId;
    final promo = await validatePromoCode(code);
    if (promo == null) throw Exception('Промокод недействителен или истёк');

    final promoId = promo['id'] as String;
    final type = promo['type'] as String? ?? 'hours';
    final value = promo['value'] as int? ?? 0;

    // Check if user already used this promo
    final existing = await _client
        .from('promo_usages')
        .select('id')
        .eq('user_id', userId)
        .eq('promo_id', promoId)
        .maybeSingle();
    if (existing != null) throw Exception('Вы уже использовали этот промокод');

    // Record usage
    await _client.from('promo_usages').insert({
      'user_id': userId,
      'promo_id': promoId,
    });

    // Increment used_count
    await _client.from('promos').update({
      'used_count': (promo['used_count'] as int? ?? 0) + 1,
    }).eq('id', promoId);

    // Apply bonus based on type
    if (type == 'hours') {
      // Add hours to active subscription
      final sub = await getActiveSubscription();
      if (sub != null) {
        await _client.from('subscriptions').update({
          'hours_balance': (sub.hoursBalance ?? 0) + value,
        }).eq('id', sub.id);
      }
    } else if (type == 'days') {
      // Extend subscription
      final sub = await getActiveSubscription();
      if (sub != null) {
        final newEnd = sub.endDate.add(Duration(days: value));
        await _client.from('subscriptions').update({
          'end_date': newEnd.toIso8601String().split('T')[0],
        }).eq('id', sub.id);
      }
    } else if (type == 'discount') {
      // Discount promos are validated at payment time, just record usage
    }

    return {
      'type': type,
      'value': value,
      'description': promo['description'] as String? ?? '',
    };
  }

  // ── Reviews ───────────────────────────────────────────────
  Future<List<Review>> getClubReviews(String clubId) async {
    final res = await _client
        .from('reviews')
        .select('*, users(name)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addReview({
    required String clubId,
    required int rating,
    String? text,
    List<String> photoUrls = const [],
  }) async {
    final userId = _userId;
    await _client.from('reviews').insert({
      'club_id': clubId,
      'user_id': userId,
      'rating': rating,
      'comment': text,
      'photo_urls': photoUrls,
    });
  }

  /// Upload review photo to Supabase Storage, returns public URL
  Future<String> uploadReviewPhoto(List<int> bytes, String fileName) async {
    final userId = _userId;
    final ext = fileName.split('.').last;
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('review-photos').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('review-photos').getPublicUrl(path);
  }

  Future<int> getUserReviewCount() async {
    final userId = currentUser?.id;
    if (userId == null) return 0;
    final res =
        await _client.from('reviews').select('id').eq('user_id', userId);
    return (res as List).length;
  }

  Future<bool> hasReviewed(String clubId) async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    final res = await _client
        .from('reviews')
        .select('id')
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .maybeSingle();
    return res != null;
  }

  // ── Referrals ─────────────────────────────────────────────
  /// Applies a referral code. The DB function `apply_referral_code`
  /// validates the code, prevents self-referral and double-use, and grants
  /// 10-hour boost to BOTH inviter and invitee atomically.
  Future<void> applyReferralCode(String code) async {
    await _client.rpc('apply_referral_code', params: {'p_code': code});
  }

  Future<Map<String, dynamic>> getReferralStats() async {
    final userId = _userId;
    try {
      final res = await _client
          .from('referral_bonuses')
          .select('*, users!referral_bonuses_invitee_id_fkey(name)')
          .eq('inviter_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      final list = res as List;
      final totalHours =
          list.fold<int>(0, (sum, v) => sum + (v['bonus_hours'] as int? ?? 3));
      return {
        'friends_count': list.length,
        'total_hours': totalHours,
        'transactions': list,
      };
    } catch (_) {
      return {'friends_count': 0, 'total_hours': 0, 'transactions': []};
    }
  }

  // ── Realtime ──────────────────────────────────────────────
  /// Subscribe to new visits for a given club via Supabase realtime.
  ///
  /// WARNING: Callers MUST unsubscribe when done, or the channel will leak
  /// (holds a websocket subscription + keeps this service / closure alive).
  /// Example:
  ///   final ch = SupabaseService().subscribeToClubVisits(clubId, _onInsert);
  ///   // later, in dispose():
  ///   Supabase.instance.client.removeChannel(ch);
  ///
  /// Currently this method has no callers in the app — if you add one,
  /// wire the unsubscribe into the owning widget/provider's dispose.
  RealtimeChannel subscribeToClubVisits(
    String clubId,
    void Function(Map<String, dynamic> payload) onInsert,
  ) {
    return _client
        .channel('club_visits_$clubId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'visits',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'club_id',
            value: clubId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }

  // ── Favorites ─────────────────────────────────────────────
  Future<List<String>> getFavoriteClubIds() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res =
        await _client.from('favorites').select('club_id').eq('user_id', userId);
    return (res as List).map((e) => e['club_id'] as String).toList();
  }

  Future<void> addFavorite(String clubId) async {
    final userId = _userId;
    await _client.from('favorites').insert({
      'user_id': userId,
      'club_id': clubId,
    });
  }

  Future<void> removeFavorite(String clubId) async {
    final userId = _userId;
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('club_id', clubId);
  }

  Future<List<Club>> getFavoriteClubs() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _client
        .from('favorites')
        .select('club_id, clubs(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => Club.fromJson(e['clubs'] as Map<String, dynamic>))
        .toList();
  }

  // ── Active Sessions ──────────────────────────────────────
  Future<Map<String, dynamic>?> getActiveSession() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final res = await _client
        .from('active_sessions')
        .select('*, clubs(name, address)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('checkin_time', ascending: false)
        .limit(1)
        .maybeSingle();
    return res;
  }

  Future<void> endSession(String sessionId) async {
    await _client.from('active_sessions').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  Future<int> getClubOccupancy(String clubId) async {
    final res = await _client
        .from('active_sessions')
        .select('id')
        .eq('club_id', clubId)
        .eq('status', 'active');
    return (res as List).length;
  }

  /// Batch occupancy for all clubs in one query
  Future<Map<String, int>> getAllClubsOccupancy() async {
    final res = await _client
        .from('active_sessions')
        .select('club_id')
        .eq('status', 'active');
    final Map<String, int> result = {};
    for (final row in (res as List)) {
      final cid = row['club_id'] as String;
      result[cid] = (result[cid] ?? 0) + 1;
    }
    return result;
  }

  // ── Achievements ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllAchievements() async {
    final res = await _client
        .from('achievements')
        .select(
            'id, name_ru, name_uz, desc_ru, desc_uz, icon, category, threshold, sort_order')
        .order('sort_order');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getUserAchievements() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _client
        .from('user_achievements')
        .select('*, achievements(*)')
        .eq('user_id', userId)
        .order('unlocked_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> unlockAchievement(String achievementId) async {
    final userId = _userId;
    await _client.from('user_achievements').upsert({
      'user_id': userId,
      'achievement_id': achievementId,
    }, onConflict: 'user_id,achievement_id');
  }

  Future<bool> hasVisitedClub(String clubId) async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    final res = await _client
        .from('visits')
        .select('id')
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
    return res != null;
  }

  // ── Gift Certificates ────────────────────────────────────
  Future<String> createGiftCertificate({
    required String plan,
    required int amountUzs,
    String? recipientName,
    String? recipientEmail,
    String? recipientPhone,
  }) async {
    final userId = _userId;
    final code = _generateGiftCode();
    await _client.from('gift_certificates').insert({
      'buyer_id': userId,
      'plan': plan,
      'amount_uzs': amountUzs,
      'code': code,
      'recipient_name': recipientName,
      'recipient_email': recipientEmail,
      'recipient_phone': recipientPhone,
      'expires_at':
          DateTime.now().add(const Duration(days: 90)).toIso8601String(),
    });
    return code;
  }

  String _generateGiftCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<List<Map<String, dynamic>>> getMyGiftCertificates() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _client
        .from('gift_certificates')
        .select()
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getGiftByCode(String code) async {
    final res = await _client
        .from('gift_certificates')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
    return res;
  }

  Future<void> redeemGiftCertificate(String code) async {
    final userId = _userId;
    final gift = await getGiftByCode(code);
    if (gift == null) throw Exception('Сертификат не найден');
    if (gift['status'] != 'paid') throw Exception('Сертификат недействителен');
    final expiresAt = DateTime.parse(gift['expires_at'] as String);
    if (expiresAt.isBefore(DateTime.now()))
      throw Exception('Сертификат просрочен');

    await _client.from('gift_certificates').update({
      'status': 'redeemed',
      'redeemed_by': userId,
      'redeemed_at': DateTime.now().toIso8601String(),
    }).eq('code', code.toUpperCase());
  }

  // ── Bookings ──────────────────────────────────────────────
  static const _gracePeriodMinutes = 15;

  Future<void> createBooking({
    required String clubId,
    required String zone,
    required DateTime bookingTime,
    required int durationHours,
  }) async {
    try {
      final userId = _userId;

      // Check if user is blocked from booking (too many no-shows)
      final userRes = await _client
          .from('users')
          .select('booking_no_shows, booking_blocked_until')
          .eq('id', userId)
          .maybeSingle();
      if (userRes != null) {
        final blockedUntil = userRes['booking_blocked_until'] as String?;
        if (blockedUntil != null &&
            DateTime.parse(blockedUntil).isAfter(DateTime.now())) {
          throw Exception(
              'Бронирование заблокировано из-за неявок. Попробуйте позже.');
        }
      }

      final endTime = bookingTime.add(Duration(hours: durationHours));
      final dateStr =
          '${bookingTime.year}-${bookingTime.month.toString().padLeft(2, '0')}-${bookingTime.day.toString().padLeft(2, '0')}';
      final startStr =
          '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}:00';
      final endStr =
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

      // Grace period = booking start time + 15 minutes
      final graceExpiresAt =
          bookingTime.add(const Duration(minutes: _gracePeriodMinutes));

      await _client.from('bookings').insert({
        'user_id': userId,
        'club_id': clubId,
        'zone': zone,
        'date': dateStr,
        'start_time': startStr,
        'end_time': endStr,
        'booking_time': bookingTime.toIso8601String(),
        'duration_hours': durationHours,
        'status': 'confirmed',
        'grace_expires_at': graceExpiresAt.toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Booking failed: ${e.message}');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Booking failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _client
        .from('bookings')
        .select(
            'id, user_id, club_id, zone, date, start_time, end_time, booking_time, duration_hours, status, grace_expires_at, clubs(name, address)')
        .eq('user_id', userId)
        .order('booking_time', ascending: false)
        .limit(20);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> cancelBooking(String bookingId) async {
    final userId = _userId;
    await _client
        .from('bookings')
        .update({
          'status': 'cancelled',
        })
        .eq('id', bookingId)
        .eq('user_id', userId);
  }

  Future<int> getUserNoShowCount() async {
    final userId = currentUser?.id;
    if (userId == null) return 0;
    final res = await _client
        .from('users')
        .select('booking_no_shows')
        .eq('id', userId)
        .maybeSingle();
    return (res?['booking_no_shows'] as int?) ?? 0;
  }

  // ── Banners ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActiveBanners() async {
    final now = DateTime.now().toIso8601String();
    final res = await _client
        .from('banners')
        .select('id, title, image_url, action_url, sort_order, expires_at')
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gte.$now')
        .order('sort_order');
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Avatar upload ─────────────────────────────────────────
  Future<String> uploadAvatar(List<int> fileBytes, String fileName) async {
    final userId = _userId;
    final ext = fileName.split('.').last;
    final path = '$userId/avatar.$ext';

    await _client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(fileBytes),
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    // Update user profile with avatar URL
    await _client
        .from('users')
        .update({'avatar_url': publicUrl}).eq('id', userId);
    return publicUrl;
  }

  // ── User language preference ─────────────────────────────
  Future<void> updateLanguage(String lang) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client
        .from('users')
        .update({'preferred_language': lang}).eq('id', userId);
  }

  // ── Visit stats ───────────────────────────────────────────
  Future<Map<String, dynamic>> getAllTimeVisitStats() async {
    final userId = _userId;
    final res = await _client
        .from('visits')
        .select('*, clubs(name, address)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final list = res as List;

    final totalHours =
        list.fold<int>(0, (sum, v) => sum + (v['hours_spent'] as int? ?? 1));

    // Find favorite club
    final Map<String, Map<String, dynamic>> clubCounts = {};
    for (final v in list) {
      final clubId = v['club_id'] as String;
      final clubs = v['clubs'] as Map<String, dynamic>?;
      if (!clubCounts.containsKey(clubId)) {
        clubCounts[clubId] = {
          'club_id': clubId,
          'name': clubs?['name'] as String? ?? '',
          'address': clubs?['address'] as String? ?? '',
          'count': 0,
        };
      }
      clubCounts[clubId]!['count'] = (clubCounts[clubId]!['count'] as int) + 1;
    }

    Map<String, dynamic>? favoriteClub;
    if (clubCounts.isNotEmpty) {
      favoriteClub = clubCounts.values.reduce(
        (a, b) => (a['count'] as int) >= (b['count'] as int) ? a : b,
      );
    }

    return {
      'total_visits': list.length,
      'total_hours': totalHours,
      'favorite_club': favoriteClub,
    };
  }

  // ── Tournaments ──────────────────────────────────────────
  Future<List<Tournament>> getTournaments(
      {String? status, String? clubId}) async {
    var q = _client
        .from('tournaments')
        .select('*, clubs(name), tournament_participants(id)');
    if (status != null) q = q.eq('status', status);
    if (clubId != null) q = q.eq('club_id', clubId);
    final res = await q.order('starts_at');
    return (res as List).map((j) {
      j['participant_count'] =
          (j['tournament_participants'] as List?)?.length ?? 0;
      return Tournament.fromJson(j);
    }).toList();
  }

  Future<Tournament> getTournamentById(String id) async {
    final res = await _client
        .from('tournaments')
        .select('*, clubs(name), tournament_participants(id)')
        .eq('id', id)
        .single();
    res['participant_count'] =
        (res['tournament_participants'] as List?)?.length ?? 0;
    return Tournament.fromJson(res);
  }

  Future<List<Map<String, dynamic>>> getTournamentParticipants(
      String tournamentId) async {
    final res = await _client
        .from('tournament_participants')
        .select('*, users(name, avatar_url)')
        .eq('tournament_id', tournamentId)
        .order('registered_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<bool> isRegisteredForTournament(String tournamentId) async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    final res = await _client
        .from('tournament_participants')
        .select('id')
        .eq('tournament_id', tournamentId)
        .eq('user_id', userId)
        .maybeSingle();
    return res != null;
  }

  Future<void> registerForTournament(String tournamentId,
      {String? teamName}) async {
    final userId = _userId;
    await _client.from('tournament_participants').insert({
      'tournament_id': tournamentId,
      'user_id': userId,
      'team_name': teamName,
    });
    // Award XP for tournament registration
    await _addXp(userId, 20, 'tournament_register', tournamentId);
  }

  Future<void> unregisterFromTournament(String tournamentId) async {
    final userId = _userId;
    await _client
        .from('tournament_participants')
        .delete()
        .eq('tournament_id', tournamentId)
        .eq('user_id', userId);
  }

  // ── Stories / News Feed ──────────────────────────────────
  Future<List<Story>> getStories({int limit = 30}) async {
    final userId = currentUser?.id;
    final res = await _client
        .from('stories')
        .select('*, clubs(name, logo_url)')
        .eq('is_active', true)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    Set<String> viewedIds = {};
    if (userId != null) {
      final views = await _client
          .from('story_views')
          .select('story_id')
          .eq('user_id', userId);
      viewedIds = (views as List).map((v) => v['story_id'] as String).toSet();
    }

    return (res as List)
        .map((j) => Story.fromJson(j, viewedIds: viewedIds))
        .toList();
  }

  Future<void> markStoryViewed(String storyId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client.from('story_views').upsert({
      'story_id': storyId,
      'user_id': userId,
    }, onConflict: 'story_id,user_id');
    // Increment views counter
    await _client.rpc('increment_story_views',
        params: {'sid': storyId}).catchError((_) {});
  }

  // ── Loyalty / XP ─────────────────────────────────────────
  Future<Map<String, dynamic>> getLoyaltyInfo() async {
    final userId = _userId;

    Map<String, dynamic> user = {};
    try {
      user = await _client
          .from('users')
          .select('xp, loyalty_level, streak_days, last_visit_date')
          .eq('id', userId)
          .single();
    } catch (_) {
      // Columns may not exist yet — fall back to defaults
      user = {};
    }

    List points = [];
    try {
      points = await _client
          .from('loyalty_points')
          .select('amount, reason, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
    } catch (_) {
      // Table may not exist yet
    }

    return {
      'xp': user['xp'] as int? ?? 0,
      'level': user['loyalty_level'] as String? ?? 'bronze',
      'streak_days': user['streak_days'] as int? ?? 0,
      'last_visit': user['last_visit_date'] as String?,
      'history': points,
    };
  }

  Future<void> _addXp(
      String userId, int amount, String reason, String? refId) async {
    try {
      await _client.from('loyalty_points').insert({
        'user_id': userId,
        'amount': amount,
        'reason': reason,
        'reference_id': refId,
      });
      // Update user XP and level
      final user =
          await _client.from('users').select('xp').eq('id', userId).single();
      final newXp = (user['xp'] as int? ?? 0) + amount;
      String level = 'bronze';
      if (newXp >= 5000)
        level = 'diamond';
      else if (newXp >= 2000)
        level = 'gold';
      else if (newXp >= 500) level = 'silver';

      await _client.from('users').update({
        'xp': newXp,
        'loyalty_level': level,
      }).eq('id', userId);
    } catch (_) {
      // loyalty_points table or xp column may not exist yet — silently skip
    }
  }

  // ── Notification Preferences ─────────────────────────────
  Future<Map<String, dynamic>> getNotificationPrefs() async {
    final userId = _userId;
    final res = await _client
        .from('notification_prefs')
        .select(
            'user_id, push_enabled, promo_enabled, tournament_enabled, subscription_enabled, club_news_enabled')
        .eq('user_id', userId)
        .maybeSingle();
    if (res != null) return res;
    // Create default prefs
    final defaults = {
      'user_id': userId,
      'push_enabled': true,
      'promo_enabled': true,
      'tournament_enabled': true,
      'subscription_enabled': true,
      'club_news_enabled': true,
    };
    await _client.from('notification_prefs').insert(defaults);
    return defaults;
  }

  Future<void> updateNotificationPrefs(Map<String, dynamic> prefs) async {
    final userId = _userId;
    await _client.from('notification_prefs').upsert({
      'user_id': userId,
      ...prefs,
      'updated_at': DateTime.now().toIso8601String()
    });
  }

  Future<void> saveFcmToken(String token) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notification_prefs')
        .upsert({'user_id': userId, 'fcm_token': token}, onConflict: 'user_id');
  }

  // ── Clubs for map (with coordinates) ─────────────────────
  Future<List<Map<String, dynamic>>> getClubsWithCoordinates() async {
    final res = await _client
        .from('clubs')
        .select('id, name, address, logo_url, latitude, longitude, status')
        .eq('status', 'active');
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Player Profiles (Game Stats) ─────────────────────────
  Future<List<Map<String, dynamic>>> getPlayerProfiles(String userId) async {
    final res = await _client
        .from('player_profiles')
        .select(
            'id, user_id, game, nickname, rank, hours_played, kd_ratio, winrate, updated_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> savePlayerProfile({
    required String game,
    required String nickname,
    String? rank,
    int? hoursPlayed,
    double? kdRatio,
    double? winrate,
  }) async {
    final userId = _userId;
    await _client.from('player_profiles').upsert({
      'user_id': userId,
      'game': game,
      'nickname': nickname,
      'rank': rank,
      'hours_played': hoursPlayed ?? 0,
      'kd_ratio': kdRatio,
      'winrate': winrate,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,game');
  }

  Future<void> deletePlayerProfile(String id) async {
    final userId = _userId;
    await _client
        .from('player_profiles')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  // ── LFG (Looking For Group) ──────────────────────────────
  Future<List<Map<String, dynamic>>> getLfgPosts({String? game}) async {
    var q = _client
        .from('lfg_posts')
        .select('*, users(name, avatar_url), clubs(name)')
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toIso8601String());
    if (game != null) q = q.eq('game', game);
    final res = await q.order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> createLfgPost({
    required String game,
    required int playersNeeded,
    String? message,
    bool micRequired = false,
    String? clubId,
  }) async {
    final userId = _userId;
    await _client.from('lfg_posts').insert({
      'user_id': userId,
      'game': game,
      'players_needed': playersNeeded,
      'message': message,
      'mic_required': micRequired,
      'club_id': clubId,
    });
    // XP for creating LFG post
    await _addXp(userId, 5, 'lfg_post', null);
  }

  Future<void> respondToLfg(String postId) async {
    final userId = _userId;
    await _client.from('lfg_responses').upsert({
      'post_id': postId,
      'user_id': userId,
    }, onConflict: 'post_id,user_id');
  }

  // ── Leaderboard ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    try {
      final res =
          await _client.rpc('get_leaderboard', params: {'limit_count': limit});
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Happy Hours ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getClubHappyHours(String clubId) async {
    final res = await _client
        .from('happy_hours')
        .select(
            'id, club_id, day_of_week, start_time, end_time, discount_percent, description')
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('day_of_week');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getActiveHappyHours() async {
    final now = DateTime.now();
    final dayOfWeek = now.weekday == 7 ? 6 : now.weekday - 1;
    final timeNow =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
    final res = await _client
        .from('happy_hours')
        .select('*, clubs(id, name, logo_url)')
        .eq('is_active', true)
        .eq('day_of_week', dayOfWeek)
        .lte('start_time', timeNow)
        .gte('end_time', timeNow);
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Nearby clubs (with distance calculation) ─────────────
  Future<List<Club>> getNearbyClubs(double userLat, double userLon,
      {double radiusKm = 10}) async {
    final clubs = await getActiveClubs();
    for (final club in clubs) {
      if (club.lat != null && club.lon != null) {
        club.distanceMeters =
            _haversine(userLat, userLon, club.lat!, club.lon!);
      }
    }
    clubs.removeWhere(
        (c) => c.distanceMeters == null || c.distanceMeters! > radiusKm * 1000);
    clubs.sort((a, b) =>
        (a.distanceMeters ?? 999999).compareTo(b.distanceMeters ?? 999999));
    return clubs;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Notifications ─────────────────────────────────────────

  /// Get user's notifications, newest first
  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await Supabase.instance.client
        .from('notifications')
        .select('id, title, body, type, event, is_read, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      // Fallback to older API
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (data as List).length;
    }
  }

  /// Mark a notification as read
  Future<void> markNotificationRead(String notifId) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true}).eq('id', notifId);
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsRead() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Subscribe to new notifications via realtime
  RealtimeChannel subscribeToNotifications(
      void Function(Map<String, dynamic>) onNew) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    return Supabase.instance.client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId),
          callback: (payload) {
            onNew(payload.newRecord);
          },
        )
        .subscribe();
  }
}
