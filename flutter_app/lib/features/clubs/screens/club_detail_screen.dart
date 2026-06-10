import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/club.dart';
import '../../booking/screens/booking_screen.dart';
import '../../../models/club_zone.dart';
import '../../../models/review.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/neon_shimmer.dart';
import '../../../core/widgets/error_retry.dart';
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
        loading: () => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              flexibleSpace: FlexibleSpaceBar(
                background: NeonShimmer(
                  borderRadius: 0,
                  child: Container(height: 250, color: context.card),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  NeonSkeletonCard(
                      height: 24, borderRadius: 8, fillColor: context.card),
                  const SizedBox(height: 12),
                  NeonSkeletonCard(
                      height: 100, borderRadius: 16, fillColor: context.card),
                  const SizedBox(height: 12),
                  NeonSkeletonCard(
                      height: 60, borderRadius: 16, fillColor: context.card),
                ]),
              ),
            ),
          ],
        ),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(clubDetailProvider(clubId)),
        ),
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

  void _call() async {
    final phone = club.contactPhone;
    if (phone == null) return;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openTelegram() async {
    if (club.contactTelegram == null) return;
    final tg = club.contactTelegram!.replaceAll('@', '');
    final url = Uri.parse('https://t.me/$tg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _share() {
    final text = '${club.name}\n${club.address}'
        '${club.contactPhone != null ? '\nТел: ${club.contactPhone}' : ''}'
        '\n\nНайдено в PlayPass';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(clubZonesProvider(club.id));
    final reviewsAsync = ref.watch(clubReviewsProvider(club.id));
    final currentSlot = AppConstants.getCurrentTimeSlot();

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(clubDetailProvider(club.id));
        ref.invalidate(clubZonesProvider(club.id));
        ref.invalidate(clubReviewsProvider(club.id));
        ref.invalidate(clubOccupancyProvider(club.id));
        await ref.read(clubDetailProvider(club.id).future);
      },
      child: CustomScrollView(
        slivers: [
          // ── Photo gallery ──────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: context.bg,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'club_image_${club.id}',
                child: club.photos.isNotEmpty
                    ? _PhotoGallery(photos: club.photos)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.3),
                              context.bg,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_esports,
                                  size: 64,
                                  color: context.text3.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text(club.name,
                                  style: TextStyle(
                                      color: context.text3, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            leading: _AppBarButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.pop(),
            ),
            actions: [
              // Share button
              _AppBarButton(
                icon: Icons.share_rounded,
                onTap: _share,
              ),
              const SizedBox(width: 4),
              // Favorite button
              Consumer(builder: (context, ref, _) {
                final isFav = ref.watch(favoritesProvider).contains(club.id);
                return _AppBarButton(
                  icon: isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: isFav ? AppTheme.error : Colors.white,
                  onTap: () =>
                      ref.read(favoritesProvider.notifier).toggle(club.id),
                );
              }),
              const SizedBox(width: 8),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Name + Tier + Status ─────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(club.name,
                                    style: TextStyle(
                                      color: context.text1,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    )),
                              ),
                              if (club.tier == 'vip') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.tierVip
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('VIP',
                                      style: TextStyle(
                                          color: AppTheme.tierVip,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Rating row
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 18, color: AppTheme.tierVip),
                              const SizedBox(width: 3),
                              Text(club.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                      color: context.text1,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(width: 6),
                              Text('(${club.reviewCount} отзывов)',
                                  style: TextStyle(
                                      color: context.text3, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (club.isOpen ? AppTheme.success : AppTheme.error)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: club.isOpen
                                  ? AppTheme.success
                                  : AppTheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            club.isOpen ? 'Открыт' : 'Закрыт',
                            style: TextStyle(
                              color: club.isOpen
                                  ? AppTheme.success
                                  : AppTheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Quick stats row ──────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _StatItem(
                          icon: Icons.computer_rounded,
                          label: '${club.pcCount} ПК',
                          color: AppTheme.primary),
                      _StatDivider(),
                      _StatItem(
                          icon: Icons.attach_money_rounded,
                          label: '${club.pricePerHour} сум/ч',
                          color: AppTheme.success),
                      if (club.hasPlaystation) ...[
                        _StatDivider(),
                        _StatItem(
                            icon: Icons.videogame_asset_rounded,
                            label: 'PS5',
                            color: AppTheme.info),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Occupancy badge ──────────────────────
                ref.watch(clubOccupancyProvider(club.id)).when(
                      data: (occupancy) => occupancy > 0
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OccupancyBadge(
                                current: occupancy,
                                capacity: club.pcCount,
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                // ── Contact info ─────────────────────────
                _InfoRow(icon: Icons.location_on_outlined, text: club.address),
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.access_time_rounded,
                    text: _getTodayHours(club)),
                if (club.contactPhone != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.phone_outlined, text: club.contactPhone!),
                ],

                const SizedBox(height: 14),

                // ── Book button ─────────────────────────
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            BookingScreen(preselectedClubId: club.id),
                      ));
                    },
                    icon: const Icon(Icons.event_seat_rounded, size: 20),
                    label: const Text('Забронировать место',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Action buttons row ───────────────────
                Row(
                  children: [
                    if (club.contactPhone != null)
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.phone_rounded,
                          label: 'Позвонить',
                          color: AppTheme.success,
                          onTap: _call,
                        ),
                      ),
                    if (club.contactPhone != null) const SizedBox(width: 8),
                    if (club.contactTelegram != null)
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.telegram,
                          label: 'Telegram',
                          color: AppTheme.telegram,
                          onTap: _openTelegram,
                        ),
                      ),
                    if (club.contactTelegram != null) const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.directions_rounded,
                        label: 'Маршрут',
                        color: AppTheme.primary,
                        onTap: () => _openMaps(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.share_rounded,
                        label: 'Поделиться',
                        color: AppTheme.info,
                        onTap: _share,
                      ),
                    ),
                  ],
                ),

                // ── Description ──────────────────────────
                if (club.description != null &&
                    club.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle(title: 'О клубе'),
                  const SizedBox(height: 8),
                  Text(
                    club.description!,
                    style: TextStyle(
                        color: context.text2, fontSize: 14, height: 1.5),
                  ),
                ],

                // ── Zones section ────────────────────────
                const SizedBox(height: 20),
                Row(
                  children: [
                    _SectionTitle(title: 'Зоны'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
                      : Column(
                          children: zones
                              .map((z) =>
                                  _ZoneCard(zone: z, currentSlot: currentSlot))
                              .toList()),
                  loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator()),
                  error: (_, __) => _buildSingleZone(),
                ),

                // ── Working hours ────────────────────────
                const SizedBox(height: 20),
                _SectionTitle(title: 'Часы работы'),
                const SizedBox(height: 8),
                _WorkingHoursTable(hours: club.workingHours),

                // ── Reviews section ──────────────────────
                const SizedBox(height: 20),
                Row(
                  children: [
                    _SectionTitle(title: 'Отзывы'),
                    const Spacer(),
                    reviewsAsync.when(
                      data: (reviews) => Text('${reviews.length}',
                          style: TextStyle(color: context.text3, fontSize: 13)),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Add review button (top)
                _AddReviewButton(club: club, ref: ref),
                const SizedBox(height: 12),

                reviewsAsync.when(
                  data: (reviews) => reviews.isEmpty
                      ? _EmptyReviewsPlaceholder()
                      : Column(
                          children: reviews
                              .take(10)
                              .map((r) => _ReviewCard(review: r))
                              .toList(),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleZone() {
    return Builder(
        builder: (context) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
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
                            style: TextStyle(
                                color: context.text1,
                                fontWeight: FontWeight.w600)),
                        if (club.pricePerHour > 0)
                          Text(
                            '${club.pricePerHour} сум/ч',
                            style:
                                TextStyle(color: context.text3, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ));
  }

  String _getTodayHours(Club club) {
    final dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayKey = dayKeys[DateTime.now().weekday - 1];
    final hours = club.workingHours[dayKey];
    if (hours == null) return 'Расписание не указано';
    if (hours == '00:00-23:59') return 'Сегодня: круглосуточно';
    return 'Сегодня: $hours';
  }
}

// ── Photo Gallery with indicators ───────────────────────────

class _PhotoGallery extends StatefulWidget {
  final List<String> photos;
  const _PhotoGallery({required this.photos});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _showFullPhoto(context, widget.photos, i),
            child: CachedNetworkImage(
              imageUrl: widget.photos[i],
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: context.surface,
                child: const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                color: context.surface,
                child: Icon(Icons.broken_image_outlined,
                    color: context.text3, size: 48),
              ),
            ),
          ),
        ),
        // Photo counter
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (i) => Container(
                  width: _current == i ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFullPhoto(
      BuildContext context, List<String> urls, int initialIndex) {
    // Use a full-screen page route on the ROOT navigator instead of showDialog.
    // showDialog inside a StatefulShellRoute can mis-route both the close-tap
    // (popping the wrong navigator) and the system back button (the dialog
    // isn't a go_router route, so back can skip it). A PageRouteBuilder on
    // the root navigator gives us a real route — close & back both work.
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            _FullPhotoViewer(urls: urls, initialIndex: initialIndex),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

/// Full-screen photo viewer with pinch-zoom, swipe between photos and a
/// reliable close button. Uses its own Navigator pop, so the back button
/// and the X always close just this overlay.
class _FullPhotoViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullPhotoViewer({required this.urls, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          // Close button — sits above the page view and uses its own context,
          // so Navigator.of(context).pop() targets THIS route deterministically.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          // Page indicator (only if multiple photos)
          if (urls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${initialIndex + 1} / ${urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── App bar button ──────────────────────────────────────────

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  const _AppBarButton(
      {required this.icon, this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? Colors.white),
      ),
      onPressed: onTap,
    );
  }
}

// ── Action button ───────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Stat items ──────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: context.text1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: context.border,
    );
  }
}

// ── Section title ───────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
          color: context.text1,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ));
  }
}

// ── Empty reviews placeholder ───────────────────────────────

class _EmptyReviewsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined,
              size: 40, color: context.text3.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text('Пока нет отзывов',
              style: TextStyle(color: context.text3, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Будьте первым, кто оставит отзыв!',
              style: TextStyle(color: context.text3, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Add review button ───────────────────────────────────────

class _AddReviewButton extends StatelessWidget {
  final Club club;
  final WidgetRef ref;
  const _AddReviewButton({required this.club, required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: context.card,
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.neonCyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_rounded, size: 18, color: AppTheme.neonCyan),
            const SizedBox(width: 8),
            Text('Оставить отзыв',
                style: TextStyle(
                    color: AppTheme.neonCyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ── Zone card ───────────────────────────────────────────────

class _ZoneCard extends StatelessWidget {
  final ClubZone zone;
  final String currentSlot;
  const _ZoneCard({required this.zone, required this.currentSlot});

  Color get _zoneColor => switch (zone.type) {
        'vip' => AppTheme.tierVip,
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
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _zoneColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _zoneColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
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
                    style: TextStyle(
                        color: context.text1, fontWeight: FontWeight.w600)),
                Text(
                  '${zone.capacity} мест  ·  $price сум/ч',
                  style: TextStyle(color: context.text3, fontSize: 12),
                ),
                if (zone.description != null)
                  Text(zone.description!,
                      style: TextStyle(color: context.text2, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Working hours table ─────────────────────────────────────

class _WorkingHoursTable extends StatelessWidget {
  final Map<String, String> hours;
  const _WorkingHoursTable({required this.hours});

  static const _dayNames = {
    'mon': 'Пн',
    'tue': 'Вт',
    'wed': 'Ср',
    'thu': 'Чт',
    'fri': 'Пт',
    'sat': 'Сб',
    'sun': 'Вс',
  };

  @override
  Widget build(BuildContext context) {
    final today = [
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun'
    ][DateTime.now().weekday - 1];

    // Check if all days are the same (24/7)
    final allSame = _dayNames.keys.every((k) => hours[k] == hours['mon']);
    if (allSame && (hours['mon'] == '00:00-23:59')) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: AppTheme.success),
            const SizedBox(width: 8),
            Text('Круглосуточно, 7 дней в неделю',
                style: TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: _dayNames.entries.map((entry) {
          final isToday = entry.key == today;
          final h = hours[entry.key] ?? 'Выходной';
          final display = h == '00:00-23:59' ? 'Круглосуточно' : h;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(entry.value,
                      style: TextStyle(
                        color: isToday ? AppTheme.primary : context.text2,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 13,
                      )),
                ),
                const SizedBox(width: 16),
                Text(display,
                    style: TextStyle(
                      color: isToday ? context.text1 : context.text3,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    )),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('сегодня',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Review card ─────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(review.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: Text(
                  (review.userName ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName ?? 'Пользователь',
                        style: TextStyle(
                            color: context.text1,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(timeAgo,
                        style: TextStyle(color: context.text3, fontSize: 11)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < review.rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: AppTheme.tierVip,
                        )),
              ),
            ],
          ),
          if (review.text != null && review.text!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.text!,
                style:
                    TextStyle(color: context.text2, fontSize: 13, height: 1.4)),
          ],
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: review.photoUrls[i],
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: context.surface,
                      child: Icon(Icons.broken_image_outlined,
                          color: context.text3, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}г назад';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}мес назад';
    if (diff.inDays > 0) return '${diff.inDays}д назад';
    if (diff.inHours > 0) return '${diff.inHours}ч назад';
    return 'только что';
  }
}

// ── Info row ────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.text3, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(color: context.text2, fontSize: 14))),
      ],
    );
  }
}
