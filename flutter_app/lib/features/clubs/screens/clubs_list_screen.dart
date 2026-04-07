import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/club.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/favorites_provider.dart';
import '../widgets/yandex_map_widget.dart';
import '../widgets/club_map_bottom_sheet.dart';

// ── Providers ──────────────────────────────────────────────

final selectedTierProvider = StateProvider<String?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');
final isMapViewProvider = StateProvider<bool>((ref) => false);
final sortModeProvider = StateProvider<String>((ref) => 'rating');
final filterPsProvider = StateProvider<bool>((ref) => false);
final filterXboxProvider = StateProvider<bool>((ref) => false);
final filterVrProvider = StateProvider<bool>((ref) => false);
// View mode: 'list' | 'map' | 'favorites'
final viewModeProvider = StateProvider<String>((ref) => 'list');

final nearbyClubsListProvider = FutureProvider<List<Club>>((ref) async {
  return SupabaseService().getNearbyClubs(41.2995, 69.2401, radiusKm: 50);
});

final clubsFilteredProvider = FutureProvider<List<Club>>((ref) async {
  final tier = ref.watch(selectedTierProvider);
  final ps = ref.watch(filterPsProvider);
  final sortMode = ref.watch(sortModeProvider);
  var clubs = await SupabaseService().getActiveClubs(tier: tier);
  if (ps) clubs = clubs.where((c) => c.hasPlaystation).toList();

  switch (sortMode) {
    case 'rating':
      clubs.sort((a, b) => b.rating.compareTo(a.rating));
    case 'price':
      clubs.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
    case 'name':
      clubs.sort((a, b) => a.name.compareTo(b.name));
  }
  return clubs;
});

final clubsOccupancyProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(clubsFilteredProvider);
  return SupabaseService().getAllClubsOccupancy();
});

// ── Screen ─────────────────────────────────────────────────

class ClubsListScreen extends ConsumerWidget {
  const ClubsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final clubsAsync = ref.watch(clubsFilteredProvider);
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Title + notification bell ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Клубы',
                    style: TextStyle(
                      color: context.text1,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: context.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.border),
                      ),
                      child: Icon(Icons.notifications_none_rounded,
                          color: context.text2, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Search bar ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 44,
                child: TextField(
                  onChanged: (v) =>
                      ref.read(searchQueryProvider.notifier).state = v,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Найти клуб или зону...',
                    hintStyle: TextStyle(color: context.text3),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: context.text3, size: 22),
                    filled: true,
                    fillColor: context.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 3 Discovery cards ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _DiscoveryCard(
                    icon: Icons.map_rounded,
                    iconColor: AppTheme.success,
                    iconBg: AppTheme.success.withValues(alpha: 0.12),
                    label: 'На карте',
                    selected: viewMode == 'map',
                    onTap: () => ref.read(viewModeProvider.notifier).state =
                        viewMode == 'map' ? 'list' : 'map',
                  ),
                  const SizedBox(width: 10),
                  _DiscoveryCard(
                    icon: Icons.sports_esports_rounded,
                    iconColor: AppTheme.primary,
                    iconBg: AppTheme.primary.withValues(alpha: 0.12),
                    label: 'По зонам',
                    selected: false,
                    onTap: () {
                      // Scroll down and show zone filters
                      ref.read(selectedTierProvider.notifier).state = null;
                      ref.read(viewModeProvider.notifier).state = 'list';
                    },
                  ),
                  const SizedBox(width: 10),
                  _DiscoveryCard(
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xFFE91E8C),
                    iconBg: const Color(0xFFE91E8C).withValues(alpha: 0.12),
                    label: 'Избранные',
                    selected: viewMode == 'favorites',
                    onTap: () => ref.read(viewModeProvider.notifier).state =
                        viewMode == 'favorites' ? 'list' : 'favorites',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Quick filter chips (horizontal scroll) ────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _QuickChip(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Свободные',
                    color: AppTheme.success,
                    selected: false,
                    onTap: () {
                      ref.read(sortModeProvider.notifier).state = 'rating';
                      ref.read(viewModeProvider.notifier).state = 'list';
                    },
                  ),
                  _QuickChip(
                    icon: Icons.star_rounded,
                    label: 'VIP',
                    color: const Color(0xFFFBBF24),
                    selected: ref.watch(selectedTierProvider) == 'vip',
                    onTap: () {
                      final t = ref.read(selectedTierProvider);
                      ref.read(selectedTierProvider.notifier).state =
                          t == 'vip' ? null : 'vip';
                      ref.read(viewModeProvider.notifier).state = 'list';
                    },
                  ),
                  _QuickChip(
                    icon: Icons.computer_rounded,
                    label: 'Стандарт',
                    color: AppTheme.primary,
                    selected: ref.watch(selectedTierProvider) == 'standard',
                    onTap: () {
                      final t = ref.read(selectedTierProvider);
                      ref.read(selectedTierProvider.notifier).state =
                          t == 'standard' ? null : 'standard';
                      ref.read(viewModeProvider.notifier).state = 'list';
                    },
                  ),
                  _QuickChip(
                    icon: Icons.videogame_asset_rounded,
                    label: 'PlayStation',
                    color: const Color(0xFF3B82F6),
                    selected: ref.watch(filterPsProvider),
                    onTap: () {
                      ref.read(filterPsProvider.notifier).state =
                          !ref.read(filterPsProvider);
                      ref.read(viewModeProvider.notifier).state = 'list';
                    },
                  ),
                  _QuickChip(
                    icon: Icons.near_me_rounded,
                    label: 'Рядом',
                    color: AppTheme.info,
                    selected: false,
                    onTap: () {
                      ref.read(viewModeProvider.notifier).state = 'list';
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Sort row ──────────────────────────────────
            if (viewMode == 'list')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.sort_rounded, size: 14, color: context.text3),
                    const SizedBox(width: 6),
                    ...['rating', 'price', 'name'].map((mode) {
                      final sortMode = ref.watch(sortModeProvider);
                      final selected = sortMode == mode;
                      final label = mode == 'rating'
                          ? 'По рейтингу'
                          : mode == 'price'
                              ? 'По цене'
                              : 'По имени';
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () =>
                              ref.read(sortModeProvider.notifier).state = mode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                  color:
                                      selected ? AppTheme.primary : context.text3,
                                  fontSize: 11,
                                  fontWeight:
                                      selected ? FontWeight.w600 : FontWeight.normal,
                                )),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // ── Content ───────────────────────────────────
            Expanded(
              child: clubsAsync.when(
                data: (clubs) {
                  final filtered = query.isEmpty
                      ? clubs
                      : clubs
                          .where((c) =>
                              c.name.toLowerCase().contains(query.toLowerCase()))
                          .toList();

                  if (viewMode == 'map') {
                    return _MapView(clubs: filtered, allClubs: clubs);
                  }
                  if (viewMode == 'favorites') {
                    return _FavoritesView(allClubs: clubs);
                  }
                  return _ListView(clubs: filtered);
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => Center(
                  child: Text('Ошибка: $e',
                      style: const TextStyle(color: AppTheme.error)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Discovery Card ──────────────────────────────────────────

class _DiscoveryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DiscoveryCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : context.border,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppTheme.primary : context.text1,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick Chip ──────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : context.text2,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map view ─────────────────────────────────────────────

class _MapView extends ConsumerWidget {
  final List<Club> clubs;
  final List<Club> allClubs;
  const _MapView({required this.clubs, required this.allClubs});

  void _showClubSheet(BuildContext context, WidgetRef ref, String clubId) {
    final match = allClubs.where((c) => c.id == clubId);
    if (match.isEmpty && clubs.isEmpty) return;
    final club = match.isNotEmpty ? match.first : clubs.first;
    final occ = ref.read(clubsOccupancyProvider).valueOrNull;
    final count = occ?[club.id] ?? 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => ClubMapBottomSheet(club: club, occupancy: count),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occ = ref.watch(clubsOccupancyProvider).valueOrNull;
    return YandexMapWidget(
      clubs: clubs,
      occupancy: occ,
      onMarkerTapped: (clubId) => _showClubSheet(context, ref, clubId),
    );
  }
}

// ── Favorites view ──────────────────────────────────────────

class _FavoritesView extends ConsumerWidget {
  final List<Club> allClubs;
  const _FavoritesView({required this.allClubs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoritesProvider);
    final favClubs = allClubs.where((c) => favIds.contains(c.id)).toList();

    if (favClubs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded,
                color: context.text3.withValues(alpha: 0.4), size: 56),
            const SizedBox(height: 12),
            Text('Нет избранных клубов',
                style: TextStyle(color: context.text3, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Нажмите на сердечко, чтобы добавить',
                style: TextStyle(color: context.text3.withValues(alpha: 0.6), fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: favClubs.map((club) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ClubListCard(club: club),
      )).toList(),
    );
  }
}

// ── List view ────────────────────────────────────────────

class _ListView extends ConsumerWidget {
  final List<Club> clubs;
  const _ListView({required this.clubs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (clubs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: context.text3, size: 48),
            const SizedBox(height: 12),
            Text('Клубы не найдены',
                style: TextStyle(color: context.text3)),
          ],
        ),
      );
    }

    final nearbyAsync = ref.watch(nearbyClubsListProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Nearby clubs horizontal section
        nearbyAsync.when(
          data: (nearby) {
            if (nearby.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text('Ближайшие',
                        style: TextStyle(
                          color: context.text1,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        )),
                    const Spacer(),
                    Text('${nearby.length} клубов',
                        style: TextStyle(color: context.text3, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: nearby.length > 8 ? 8 : nearby.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _NearbyClubChip(
                      club: nearby[i],
                      onTap: () => context.push('/clubs/${nearby[i].id}'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Section title
        Row(
          children: [
            Text('Все клубы',
                style: TextStyle(
                  color: context.text1,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )),
            const Spacer(),
            Text('${clubs.length}',
                style: TextStyle(color: context.text3, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 10),

        ...clubs.map((club) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ClubListCard(club: club),
            )),
      ],
    );
  }
}

class _NearbyClubChip extends StatelessWidget {
  final Club club;
  final VoidCallback onTap;
  const _NearbyClubChip({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: club.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: club.thumbnail!,
                      width: 120,
                      height: 65,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 120,
                      height: 65,
                      color: context.surface,
                      child: Icon(Icons.sports_esports,
                          color: context.text3, size: 24),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.text1,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: club.isOpen ? AppTheme.success : AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(club.isOpen ? 'Открыт' : 'Закрыт',
                          style: TextStyle(
                            color:
                                club.isOpen ? AppTheme.success : AppTheme.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
                      if (club.distanceMeters != null) ...[
                        const Spacer(),
                        Text(club.distanceText,
                            style: TextStyle(
                                color: context.text3, fontSize: 9)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Club list card ──────────────────────────────────────────

class _ClubListCard extends ConsumerWidget {
  final Club club;
  const _ClubListCard({required this.club});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).contains(club.id);

    return GestureDetector(
      onTap: () => context.push('/clubs/${club.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: club.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: club.thumbnail!,
                      width: 100,
                      height: 110,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 100,
                      height: 110,
                      color: context.surface,
                      child: Icon(Icons.sports_esports,
                          color: context.text3, size: 36),
                    ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            club.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.text1,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (club.tier == 'vip')
                          _Badge(
                              label: 'VIP',
                              color: const Color(0xFFFBBF24)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              ref.read(favoritesProvider.notifier).toggle(club.id),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav ? AppTheme.error : context.text3,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13, color: context.text3),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            club.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: context.text3, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (club.hasPlaystation)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 4,
                          children: [
                            _Badge(
                                label: 'PS',
                                color: const Color(0xFF3B82F6)),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 2),
                        Text(
                          club.rating.toStringAsFixed(1),
                          style:
                              TextStyle(color: context.text2, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.computer, size: 14, color: context.text3),
                        const SizedBox(width: 2),
                        Text(
                          '${club.pcCount} ПК',
                          style:
                              TextStyle(color: context.text3, fontSize: 12),
                        ),
                        Consumer(builder: (_, ref, __) {
                          final occ =
                              ref.watch(clubsOccupancyProvider).valueOrNull;
                          final count = occ?[club.id] ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          final pct = club.pcCount > 0
                              ? (count / club.pcCount * 100).round()
                              : 0;
                          final color = pct > 80
                              ? AppTheme.error
                              : pct > 50
                                  ? AppTheme.warning
                                  : AppTheme.success;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('$pct%',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          );
                        }),
                        const Spacer(),
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: club.isOpen
                                ? AppTheme.success
                                : AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          club.isOpen ? 'Открыт' : 'Закрыт',
                          style: TextStyle(
                            color: club.isOpen
                                ? AppTheme.success
                                : AppTheme.error,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
