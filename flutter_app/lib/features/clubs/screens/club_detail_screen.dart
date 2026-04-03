import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/club.dart';
import '../../../models/club_zone.dart';
import '../../../models/review.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/favorites_provider.dart';
import '../widgets/add_review_dialog.dart';
import '../widgets/occupancy_badge.dart';

final clubDetailProvider =
    FutureProvider.family<Club?, String>((ref, id) async {
  return SupabaseService().getClub(id);
});

final clubZonesProvider =
    FutureProvider.family<List<ClubZone>, String>((ref, id) async {
  return SupabaseService().getClubZones(id);
});

final clubReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, id) async {
  return SupabaseService().getClubReviews(id);
});

final clubOccupancyProvider =
    FutureProvider.family<int, String>((ref, id) async {
  return SupabaseService().getClubOccupancy(id);
});

class ClubDetailScreen extends ConsumerWidget {
  final String clubId;
  const ClubDetailScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(clubDetailProvider(clubId));

    return Scaffold(
      body: clubAsync.when(
        data: (club) => club == null
            ? const Center(child: Text('Клуб не найден'))
            : _ClubDetail(club: club),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}

class _ClubDetail extends ConsumerWidget {
  final Club club;
  const _ClubDetail({required this.club});

  void _openMaps(BuildContext context) async {
    if (club.lat == null || club.lon == null) return;
    final url = Uri.parse(
      'https://yandex.ru/maps/?rtext=~${club.lat},${club.lon}&rtt=auto',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(clubZonesProvider(club.id));
    final reviewsAsync = ref.watch(clubReviewsProvider(club.id));
    final currentSlot = AppConstants.getCurrentTimeSlot();

    return CustomScrollView(
      slivers: [
        // Photo gallery
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: AppTheme.bgDark,
          flexibleSpace: FlexibleSpaceBar(
            background: club.photos.isNotEmpty
                ? PageView.builder(
                    itemCount: club.photos.length,
                    itemBuilder: (_, i) => CachedNetworkImage(
                      imageUrl: club.photos[i],
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    color: AppTheme.bgCard,
                    child: const Icon(Icons.sports_esports,
                        size: 80, color: AppTheme.textMuted),
                  ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back_ios, size: 18),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            Consumer(builder: (context, ref, _) {
              final isFav = ref.watch(favoritesProvider).contains(club.id);
              return IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? AppTheme.error : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => ref.read(favoritesProvider.notifier).toggle(club.id),
              );
            }),
            const SizedBox(width: 4),
          ],
        ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Name + Status
              Row(
                children: [
                  Expanded(
                    child: Text(club.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (club.isOpen ? AppTheme.success : AppTheme.error)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      club.isOpen ? 'Открыт' : 'Закрыт',
                      style: TextStyle(
                        color: club.isOpen ? AppTheme.success : AppTheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Rating + Review count
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 18, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 4),
                  Text(
                    '${club.rating.toStringAsFixed(1)}  ·  ${club.reviewCount} отзывов  ·  ${club.pcCount} ПК',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Occupancy badge
              ref.watch(clubOccupancyProvider(club.id)).when(
                data: (occupancy) => occupancy > 0
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OccupancyBadge(
                          current: occupancy,
                          capacity: club.pcCount,
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),

              // Address + Hours
              _InfoRow(icon: Icons.location_on_outlined, text: club.address),
              const SizedBox(height: 8),
              _InfoRow(
                  icon: Icons.access_time_rounded,
                  text: _getTodayHours(club)),

              // Description
              if (club.description != null && club.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('О клубе',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  club.description!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],

              // Zones section
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Зоны',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppConstants.timeSlotLabel(currentSlot),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              zonesAsync.when(
                data: (zones) => zones.isEmpty
                    ? _buildSingleZone()
                    : Column(children: zones.map((z) => _ZoneCard(zone: z, currentSlot: currentSlot)).toList()),
                loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()),
                error: (_, __) => _buildSingleZone(),
              ),

              // Working hours
              const SizedBox(height: 20),
              Text('Часы работы',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _WorkingHoursTable(hours: club.workingHours),

              // Reviews section
              const SizedBox(height: 20),
              Text('Отзывы',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              reviewsAsync.when(
                data: (reviews) => reviews.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Пока нет отзывов',
                            style: TextStyle(color: AppTheme.textMuted)),
                      )
                    : Column(
                        children: reviews.take(5).map((r) => _ReviewCard(review: r)).toList(),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Add review button
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.bgCard,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => AddReviewDialog(
                      clubId: club.id,
                      clubName: club.name,
                      onSubmitted: () => ref.invalidate(clubReviewsProvider(club.id)),
                    ),
                  );
                },
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Оставить отзыв'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.neonCyan,
                  side: BorderSide(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),

              const SizedBox(height: 24),

              // Navigate button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _openMaps(context),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Построить маршрут'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleZone() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Базовая',
                style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${club.pcCount} ПК',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                if (club.pricePerHour > 0)
                  Text(
                    '${club.pricePerHour} UZS/ч',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTodayHours(Club club) {
    final dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayKey = dayKeys[DateTime.now().weekday - 1];
    final hours = club.workingHours[dayKey];
    if (hours == null) return 'Расписание не указано';
    return 'Сегодня: $hours';
  }
}

// ── Zone card ─────────────────────────────────────────────
class _ZoneCard extends StatelessWidget {
  final ClubZone zone;
  final String currentSlot;
  const _ZoneCard({required this.zone, required this.currentSlot});

  Color get _zoneColor => switch (zone.type) {
    'vip' => const Color(0xFFFBBF24),
    'pro' => AppTheme.primary,
    _ => AppTheme.success,
  };

  @override
  Widget build(BuildContext context) {
    final price = zone.priceForSlot(currentSlot);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _zoneColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: _zoneColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _zoneColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(zone.typeLabel,
                style: TextStyle(
                    color: _zoneColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${zone.capacity} мест · $price UZS/ч',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
                if (zone.description != null)
                  Text(zone.description!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Working hours table ───────────────────────────────────
class _WorkingHoursTable extends StatelessWidget {
  final Map<String, String> hours;
  const _WorkingHoursTable({required this.hours});

  static const _dayNames = {
    'mon': 'Пн', 'tue': 'Вт', 'wed': 'Ср', 'thu': 'Чт',
    'fri': 'Пт', 'sat': 'Сб', 'sun': 'Вс',
  };

  @override
  Widget build(BuildContext context) {
    final today = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][DateTime.now().weekday - 1];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
        boxShadow: AppTheme.cardGlow(),
      ),
      child: Column(
        children: _dayNames.entries.map((entry) {
          final isToday = entry.key == today;
          final h = hours[entry.key] ?? 'Выходной';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(entry.value,
                      style: TextStyle(
                        color: isToday ? AppTheme.primary : AppTheme.textSecondary,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 13,
                      )),
                ),
                const SizedBox(width: 16),
                Text(h,
                    style: TextStyle(
                      color: isToday ? AppTheme.textPrimary : AppTheme.textMuted,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(review.userName ?? 'Пользователь',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              ...List.generate(5, (i) => Icon(
                i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: const Color(0xFFFBBF24),
              )),
            ],
          ),
          if (review.text != null && review.text!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.text!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14))),
      ],
    );
  }
}
