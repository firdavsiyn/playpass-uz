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
  final SupabaseClient _client = Supabase.instance.client;

  // ── Auth ──────────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Users ─────────────────────────────────────────────────
  Future<void> updateUserProfile({required String name, String? avatarUrl}) async {
    final userId = currentUser!.id;
    await _client.from('users').upsert({
      'id': userId,
      'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final res = await _client.from('users').select().eq('id', userId).maybeSingle();
    return res;
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

  // ── Freeze / Unfreeze ────────────────────────────────────
  Future<void> freezeSubscription(String subscriptionId, int days) async {
    final userId = currentUser!.id;
    await _client.from('subscriptions').update({
      'status': 'frozen',
      'frozen_since': DateTime.now().toIso8601String().split('T')[0],
    }).eq('id', subscriptionId).eq('user_id', userId);
  }

  Future<void> unfreezeSubscription(String subscriptionId) async {
    final userId = currentUser!.id;
    final sub = await _client.from('subscriptions')
        .select()
        .eq('id', subscriptionId)
        .eq('user_id', userId)
        .single();

    if (sub['frozen_since'] == null) {
      await _client.from('subscriptions').update({
        'status': 'active',
        'frozen_since': null,
      }).eq('id', subscriptionId);
      return;
    }
    final frozenSince = DateTime.parse(sub['frozen_since'] as String);
    final frozenDays = DateTime.now().difference(frozenSince).inDays;
    final oldEnd = DateTime.parse(sub['end_date'] as String);
    final newEnd = oldEnd.add(Duration(days: frozenDays));
    final oldUsed = sub['frozen_days_used'] as int? ?? 0;

    await _client.from('subscriptions').update({
      'status': 'active',
      'frozen_since': null,
      'frozen_days_used': oldUsed + frozenDays,
      'end_date': newEnd.toIso8601String().split('T')[0],
    }).eq('id', subscriptionId).eq('user_id', userId);
  }

  // ── Subscription Requests (ручная оплата) ─────────────────
  Future<void> createSubscriptionRequest({
    required String plan,
    required int amountUzs,
    required String userPhone,
    String? paymentNote,
  }) async {
    final userId = currentUser!.id;
    await _client.from('subscription_requests').insert({
      'user_id': userId,
      'plan': plan,
      'amount_uzs': amountUzs,
      'user_phone': userPhone,
      'payment_note': paymentNote,
    });
  }

  Future<List<SubscriptionRequest>> getMySubscriptionRequests() async {
    final userId = currentUser!.id;
    final res = await _client
        .from('subscription_requests')
        .select()
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
  Future<List<Club>> getActiveClubs({String? tier}) async {
    var query = _client
        .from('clubs')
        .select()
        .eq('status', 'active');

    if (tier != null) {
      query = query.eq('tier', tier);
    }

    final res = await query.order('rating', ascending: false);
    return (res as List).map((e) => Club.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Club?> getClub(String clubId) async {
    final res = await _client.from('clubs').select().eq('id', clubId).maybeSingle();
    if (res == null) return null;
    return Club.fromJson(res);
  }

  // ── Club Zones ────────────────────────────────────────────
  Future<List<ClubZone>> getClubZones(String clubId) async {
    final res = await _client
        .from('club_zones')
        .select()
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('type');
    return (res as List).map((e) => ClubZone.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Visits ────────────────────────────────────────────────
  Future<List<Visit>> getVisitHistory({int? month, int? year}) async {
    final userId = currentUser!.id;
    var query = _client
        .from('visits')
        .select('*, clubs(name)')
        .eq('user_id', userId);

    if (month != null && year != null) {
      final from = DateTime(year, month, 1);
      final to = DateTime(year, month + 1, 0, 23, 59, 59);
      query = query
          .gte('created_at', from.toIso8601String())
          .lte('created_at', to.toIso8601String());
    }

    final res = await query.order('created_at', ascending: false);
    return (res as List).map((e) => Visit.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Checkin ───────────────────────────────────────────────
  Future<Map<String, dynamic>> checkin({
    required String zoneId,
    required String qrHmac,
    double? geoLat,
    double? geoLon,
  }) async {
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
    if (expiresAt != null && DateTime.parse(expiresAt).isBefore(DateTime.now())) {
      return null;
    }

    // Check usage limit
    final maxUses = res['max_uses'] as int? ?? 0;
    final usedCount = res['used_count'] as int? ?? 0;
    if (maxUses > 0 && usedCount >= maxUses) return null;

    return res;
  }

  Future<Map<String, dynamic>> applyPromoCode(String code) async {
    final userId = currentUser!.id;
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
    return (res as List).map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addReview({
    required String clubId,
    required int rating,
    String? text,
    List<String> photoUrls = const [],
  }) async {
    final userId = currentUser!.id;
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
    final userId = currentUser!.id;
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
    final res = await _client
        .from('reviews')
        .select('id')
        .eq('user_id', userId);
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
  Future<void> applyReferralCode(String code) async {
    final userId = currentUser!.id;
    await _client.functions.invoke(
      'apply-referral',
      body: {
        'referral_code': code,
        'invitee_id': userId,
      },
    );
  }

  Future<Map<String, dynamic>> getReferralStats() async {
    final userId = currentUser!.id;
    final res = await _client
        .from('referral_transactions')
        .select('*, users!referral_transactions_invitee_id_fkey(name)')
        .eq('inviter_id', userId)
        .order('created_at', ascending: false)
        .limit(10);
    final list = res as List;
    final totalHours = list.fold<int>(0, (sum, v) => sum + (v['bonus_hours'] as int? ?? 3));
    return {
      'friends_count': list.length,
      'total_hours': totalHours,
      'transactions': list,
    };
  }

  // ── Realtime ──────────────────────────────────────────────
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
    final res = await _client
        .from('favorites')
        .select('club_id')
        .eq('user_id', userId);
    return (res as List).map((e) => e['club_id'] as String).toList();
  }

  Future<void> addFavorite(String clubId) async {
    final userId = currentUser!.id;
    await _client.from('favorites').insert({
      'user_id': userId,
      'club_id': clubId,
    });
  }

  Future<void> removeFavorite(String clubId) async {
    final userId = currentUser!.id;
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
        .select()
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
    final userId = currentUser!.id;
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
    final userId = currentUser!.id;
    final code = _generateGiftCode();
    await _client.from('gift_certificates').insert({
      'buyer_id': userId,
      'plan': plan,
      'amount_uzs': amountUzs,
      'code': code,
      'recipient_name': recipientName,
      'recipient_email': recipientEmail,
      'recipient_phone': recipientPhone,
      'expires_at': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
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
    final userId = currentUser!.id;
    final gift = await getGiftByCode(code);
    if (gift == null) throw Exception('Сертификат не найден');
    if (gift['status'] != 'paid') throw Exception('Сертификат недействителен');
    final expiresAt = DateTime.parse(gift['expires_at'] as String);
    if (expiresAt.isBefore(DateTime.now())) throw Exception('Сертификат просрочен');

    await _client.from('gift_certificates').update({
      'status': 'redeemed',
      'redeemed_by': userId,
      'redeemed_at': DateTime.now().toIso8601String(),
    }).eq('code', code.toUpperCase());
  }

  // ── Bookings ──────────────────────────────────────────────
  Future<void> createBooking({
    required String clubId,
    required String zone,
    required DateTime bookingTime,
    required int durationHours,
  }) async {
    final userId = currentUser!.id;
    final endTime = bookingTime.add(Duration(hours: durationHours));
    final dateStr = '${bookingTime.year}-${bookingTime.month.toString().padLeft(2, '0')}-${bookingTime.day.toString().padLeft(2, '0')}';
    final startStr = '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}:00';
    final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
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
    });
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final res = await _client
        .from('bookings')
        .select('*, clubs(name)')
        .eq('user_id', userId)
        .order('booking_time', ascending: false)
        .limit(20);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> cancelBooking(String bookingId) async {
    final userId = currentUser!.id;
    await _client.from('bookings').update({
      'status': 'cancelled',
    }).eq('id', bookingId).eq('user_id', userId);
  }

  // ── Banners ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActiveBanners() async {
    final now = DateTime.now().toIso8601String();
    final res = await _client
        .from('banners')
        .select()
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gte.$now')
        .order('sort_order');
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Avatar upload ─────────────────────────────────────────
  Future<String> uploadAvatar(List<int> fileBytes, String fileName) async {
    final userId = currentUser!.id;
    final ext = fileName.split('.').last;
    final path = '$userId/avatar.$ext';

    await _client.storage.from('avatars').uploadBinary(
      path,
      Uint8List.fromList(fileBytes),
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    // Update user profile with avatar URL
    await _client.from('users').update({'avatar_url': publicUrl}).eq('id', userId);
    return publicUrl;
  }

  // ── User language preference ─────────────────────────────
  Future<void> updateLanguage(String lang) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client.from('users').update({'preferred_language': lang}).eq('id', userId);
  }

  // ── Visit stats ───────────────────────────────────────────
  Future<Map<String, dynamic>> getAllTimeVisitStats() async {
    final userId = currentUser!.id;
    final res = await _client
        .from('visits')
        .select('*, clubs(name, address)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final list = res as List;

    final totalHours = list.fold<int>(0, (sum, v) => sum + (v['hours_deducted'] as int? ?? 1));

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
  Future<List<Tournament>> getTournaments({String? status, String? clubId}) async {
    var q = _client.from('tournaments')
        .select('*, clubs(name), tournament_participants(id)');
    if (status != null) q = q.eq('status', status);
    if (clubId != null) q = q.eq('club_id', clubId);
    final res = await q.order('starts_at');
    return (res as List).map((j) {
      j['participant_count'] = (j['tournament_participants'] as List?)?.length ?? 0;
      return Tournament.fromJson(j);
    }).toList();
  }

  Future<Tournament> getTournamentById(String id) async {
    final res = await _client.from('tournaments')
        .select('*, clubs(name), tournament_participants(id)')
        .eq('id', id)
        .single();
    res['participant_count'] = (res['tournament_participants'] as List?)?.length ?? 0;
    return Tournament.fromJson(res);
  }

  Future<List<Map<String, dynamic>>> getTournamentParticipants(String tournamentId) async {
    final res = await _client.from('tournament_participants')
        .select('*, users(name, avatar_url)')
        .eq('tournament_id', tournamentId)
        .order('registered_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<bool> isRegisteredForTournament(String tournamentId) async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    final res = await _client.from('tournament_participants')
        .select('id')
        .eq('tournament_id', tournamentId)
        .eq('user_id', userId)
        .maybeSingle();
    return res != null;
  }

  Future<void> registerForTournament(String tournamentId, {String? teamName}) async {
    final userId = currentUser!.id;
    await _client.from('tournament_participants').insert({
      'tournament_id': tournamentId,
      'user_id': userId,
      'team_name': teamName,
    });
    // Award XP for tournament registration
    await _addXp(userId, 20, 'tournament_register', tournamentId);
  }

  Future<void> unregisterFromTournament(String tournamentId) async {
    final userId = currentUser!.id;
    await _client.from('tournament_participants')
        .delete()
        .eq('tournament_id', tournamentId)
        .eq('user_id', userId);
  }

  // ── Stories / News Feed ──────────────────────────────────
  Future<List<Story>> getStories({int limit = 30}) async {
    final userId = currentUser?.id;
    final res = await _client.from('stories')
        .select('*, clubs(name, logo_url)')
        .eq('is_active', true)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    Set<String> viewedIds = {};
    if (userId != null) {
      final views = await _client.from('story_views')
          .select('story_id')
          .eq('user_id', userId);
      viewedIds = (views as List).map((v) => v['story_id'] as String).toSet();
    }

    return (res as List).map((j) => Story.fromJson(j, viewedIds: viewedIds)).toList();
  }

  Future<void> markStoryViewed(String storyId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client.from('story_views').upsert({
      'story_id': storyId,
      'user_id': userId,
    }, onConflict: 'story_id,user_id');
    // Increment views counter
    await _client.rpc('increment_story_views', params: {'sid': storyId}).catchError((_) {});
  }

  // ── Loyalty / XP ─────────────────────────────────────────
  Future<Map<String, dynamic>> getLoyaltyInfo() async {
    final userId = currentUser!.id;
    final user = await _client.from('users')
        .select('xp, loyalty_level, streak_days, last_visit_date')
        .eq('id', userId)
        .single();

    final points = await _client.from('loyalty_points')
        .select('amount, reason, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return {
      'xp': user['xp'] as int? ?? 0,
      'level': user['loyalty_level'] as String? ?? 'bronze',
      'streak_days': user['streak_days'] as int? ?? 0,
      'last_visit': user['last_visit_date'] as String?,
      'history': points,
    };
  }

  Future<void> _addXp(String userId, int amount, String reason, String? refId) async {
    await _client.from('loyalty_points').insert({
      'user_id': userId,
      'amount': amount,
      'reason': reason,
      'reference_id': refId,
    });
    // Update user XP and level
    final user = await _client.from('users').select('xp').eq('id', userId).single();
    final newXp = (user['xp'] as int? ?? 0) + amount;
    String level = 'bronze';
    if (newXp >= 5000) level = 'diamond';
    else if (newXp >= 2000) level = 'gold';
    else if (newXp >= 500) level = 'silver';

    await _client.from('users').update({
      'xp': newXp,
      'loyalty_level': level,
    }).eq('id', userId);
  }

  // ── Notification Preferences ─────────────────────────────
  Future<Map<String, dynamic>> getNotificationPrefs() async {
    final userId = currentUser!.id;
    final res = await _client.from('notification_prefs')
        .select()
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
    final userId = currentUser!.id;
    await _client.from('notification_prefs')
        .upsert({'user_id': userId, ...prefs, 'updated_at': DateTime.now().toIso8601String()});
  }

  Future<void> saveFcmToken(String token) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await _client.from('notification_prefs')
        .upsert({'user_id': userId, 'fcm_token': token}, onConflict: 'user_id');
  }

  // ── Clubs for map (with coordinates) ─────────────────────
  Future<List<Map<String, dynamic>>> getClubsWithCoordinates() async {
    final res = await _client.from('clubs')
        .select('id, name, address, logo_url, latitude, longitude, status')
        .eq('status', 'active');
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Player Profiles (Game Stats) ─────────────────────────
  Future<List<Map<String, dynamic>>> getPlayerProfiles(String userId) async {
    final res = await _client.from('player_profiles')
        .select()
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
    final userId = currentUser!.id;
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
    final userId = currentUser!.id;
    await _client.from('player_profiles').delete().eq('id', id).eq('user_id', userId);
  }

  // ── LFG (Looking For Group) ──────────────────────────────
  Future<List<Map<String, dynamic>>> getLfgPosts({String? game}) async {
    var q = _client.from('lfg_posts')
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
    final userId = currentUser!.id;
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
    final userId = currentUser!.id;
    await _client.from('lfg_responses').upsert({
      'post_id': postId,
      'user_id': userId,
    }, onConflict: 'post_id,user_id');
  }

  // ── Leaderboard ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    final res = await _client.from('users')
        .select('id, name, avatar_url, xp, loyalty_level, total_visits')
        .order('xp', ascending: false)
        .limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Happy Hours ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getClubHappyHours(String clubId) async {
    final res = await _client.from('happy_hours')
        .select()
        .eq('club_id', clubId)
        .eq('is_active', true)
        .order('day_of_week');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getActiveHappyHours() async {
    final now = DateTime.now();
    final dayOfWeek = now.weekday == 7 ? 6 : now.weekday - 1;
    final timeNow = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
    final res = await _client.from('happy_hours')
        .select('*, clubs(id, name, logo_url)')
        .eq('is_active', true)
        .eq('day_of_week', dayOfWeek)
        .lte('start_time', timeNow)
        .gte('end_time', timeNow);
    return (res as List).cast<Map<String, dynamic>>();
  }

  // ── Nearby clubs (with distance calculation) ─────────────
  Future<List<Club>> getNearbyClubs(double userLat, double userLon, {double radiusKm = 10}) async {
    final clubs = await getActiveClubs();
    for (final club in clubs) {
      if (club.lat != null && club.lon != null) {
        club.distanceMeters = _haversine(userLat, userLon, club.lat!, club.lon!);
      }
    }
    clubs.removeWhere((c) => c.distanceMeters == null || c.distanceMeters! > radiusKm * 1000);
    clubs.sort((a, b) => (a.distanceMeters ?? 999999).compareTo(b.distanceMeters ?? 999999));
    return clubs;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final a = _sin2(dLat / 2) + _cos(lat1 * 3.141592653589793 / 180) * _cos(lat2 * 3.141592653589793 / 180) * _sin2(dLon / 2);
    return r * 2 * _atan2(_sqrt(a), _sqrt(1 - a));
  }

  double _sin2(double x) { final s = _sin(x); return s * s; }
  double _sin(double x) => x - (x*x*x)/6 + (x*x*x*x*x)/120 - (x*x*x*x*x*x*x)/5040;
  double _cos(double x) => 1 - (x*x)/2 + (x*x*x*x)/24 - (x*x*x*x*x*x)/720;
  double _sqrt(double x) { double g = x / 2; for (int i = 0; i < 10; i++) g = (g + x / g) / 2; return g; }
  double _atan2(double y, double x) { if (x > 0) return _atan(y / x); if (x < 0) return _atan(y / x) + 3.141592653589793; return y > 0 ? 1.5707963 : -1.5707963; }
  double _atan(double x) => x - (x*x*x)/3 + (x*x*x*x*x)/5 - (x*x*x*x*x*x*x)/7;
}
