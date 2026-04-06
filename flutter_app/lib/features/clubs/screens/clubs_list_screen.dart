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

// Console filters
final filterPsProvider = StateProvider<bool>((ref) => false);

// Nearby clubs (using device location or Tashkent center as default)
final nearbyClubsListProvider = FutureProvider<List<Club>>((ref) async {
  // Default: Tashkent center coordinates
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

// Occupancy for list display — single batch query instead of N+1
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
    final isMap = ref.watch(isMapViewProvider);
    final tier = ref.watch(selectedTierProvider);
    final ps = ref.watch(filterPsProvider);

    return Scaffold(
      body: Column(
        children: [
          // ── Header area: search + toggle + filters ────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Search bar + toggle row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Search field
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            onChanged: (v) =>
                                ref.read(searchQueryProvider.notifier).state = v,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Поиск клуба...',
                              prefixIcon:
                                  Icon(Icons.search, color: context.text3, size: 20),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Map / List toggle
                      _ViewToggle(
                        isMap: isMap,
                        onToggle: () => ref
                            .read(isMapViewProvider.notifier)
                            .state = !isMap,
                      ),
                    ],
                  ),
                ),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Все',
                        icon: Icons.apps,
                        selected: tier == null && !ps,
                        onTap: () {
                          ref.read(selectedTierProvider.notifier).state = null;
                          ref.read(filterPsProvider.notifier).state = false;
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'VIP',
                        icon: Icons.star_rounded,
                        selected: tier == 'vip',
                        onTap: () =>
                            ref.read(selectedTierProvider.notifier).state =
                                tier == 'vip' ? null : 'vip',
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Стандарт',
                        icon: Icons.computer,
                        selected: tier == 'standard',
                        onTap: () =>
                            ref.read(selectedTierProvider.notifier).state =
                                tier == 'standard' ? null : 'standard',
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'PlayStation',
                        icon: Icons.videogame_asset_rounded,
                        selected: ps,
                        onTap: () =>
                            ref.read(filterPsProvider.notifier).state = !ps,
                      ),
                    ],
                  ),
                ),

                // Sort row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.sort_rounded, size: 14, color: context.text3),
                      const SizedBox(width: 6),
                      ...['rating', 'price', 'name'].map((mode) {
                        final sortMode = ref.watch(sortModeProvider);
                        final selected = sortMode == mode;
                        final label = mode == 'rating' ? 'По рейтингу' :
                            mode == 'price' ? 'По цене' : 'По имени';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => ref.read(sortModeProvider.notifier).state = mode,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                    color: selected ? AppTheme.primary : context.text3,
                                    fontSize: 11,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                  )),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Content: map or list ──────────────────────────
          Expanded(
            child: clubsAsync.when(
              data: (clubs) {
                final filtered = query.isEmpty
                    ? clubs
                    : clubs
                        .where((c) =>
                            c.name.toLowerCase().contains(query.toLowerCase()))
                        .toList();

                if (isMap) {
                  return _MapView(clubs: filtered, allClubs: clubs);
                }
                return _ListView(clubs: filtered);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Ошибка: $e',
                    style: const TextStyle(color: AppTheme.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map/List toggle button ───────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool isMap;
  final VoidCallback onToggle;
  const _ViewToggle({required this.isMap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: [
            _ToggleItem(
              icon: Icons.list_rounded,
              label: 'Список',
              selected: !isMap,
            ),
            _ToggleItem(
              icon: Icons.map_rounded,
              label: 'Карта',
              selected: isMap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _ToggleItem(
      {required this.icon, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : context.text3),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.text3,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map view ─────────────────────────────────────────────

class _MapView extends ConsumerWidget {
  final List<Club> clubs;
  final List<Club> allClubs;
  const _MapView({required this.clubs, required this.allClubs});

  void _showClubSheet(BuildContext context, String clubId) {
    final match = allClubs.where((c) => c.id == clubId);
    if (match.isEmpty && clubs.isEmpty) return;
    final club = match.isNotEmpty ? match.first : clubs.first;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => ClubMapBottomSheet(club: club),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return YandexMapWidget(
      clubs: clubs,
      onMarkerTapped: (clubId) => _showClubSheet(context, clubId),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                    const Icon(Icons.near_me_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text('Ближайшие клубы',
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
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // All clubs
        Text('Все клубы',
            style: TextStyle(
              color: context.text1,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            )),
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
    final name = club.name;
    final thumbnail = club.thumbnail;
    final isOpen = club.isOpen;

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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: thumbnail,
                      width: 120,
                      height: 65,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 120,
                      height: 65,
                      color: context.surface,
                      child: Icon(Icons.sports_esports, color: context.text3, size: 24),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
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
                          color: isOpen ? AppTheme.success : AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(isOpen ? 'Открыт' : 'Закрыт',
                          style: TextStyle(
                            color: isOpen ? AppTheme.success : AppTheme.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
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

// ── Filter chip ────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : context.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: selected ? Colors.white : context.text3),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : context.text2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── List card ──────────────────────────────────────────────

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
            // Photo
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
                    // Name + tier badge + heart
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
                          onTap: () => ref.read(favoritesProvider.notifier).toggle(club.id),
                          child: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? AppTheme.error : context.text3,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Address
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
                            style: TextStyle(
                                color: context.text3, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Console badges
                    if (club.hasPlaystation)
                      Wrap(
                        spacing: 4,
                        children: [
                          _Badge(
                              label: 'PS', color: const Color(0xFF3B82F6)),
                        ],
                      ),
                    if (club.hasPlaystation)
                      const SizedBox(height: 6),
                    // Rating + PC + status
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 2),
                        Text(
                          club.rating.toStringAsFixed(1),
                          style: TextStyle(
                              color: context.text2, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.computer,
                            size: 14, color: context.text3),
                        const SizedBox(width: 2),
                        Text(
                          '${club.pcCount} ПК',
                          style: TextStyle(
                              color: context.text3, fontSize: 12),
                        ),
                        // Occupancy indicator
                        Consumer(builder: (_, ref, __) {
                          final occ = ref.watch(clubsOccupancyProvider).valueOrNull;
                          final count = occ?[club.id] ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          final pct = club.pcCount > 0 ? (count / club.pcCount * 100).round() : 0;
                          final color = pct > 80 ? AppTheme.error : pct > 50 ? AppTheme.warning : AppTheme.success;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('$pct%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          );
                        }),
                        const Spacer(),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color:
                                club.isOpen ? AppTheme.success : AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          club.isOpen ? 'Открыт' : 'Закрыт',
                          style: TextStyle(
                            color:
                                club.isOpen ? AppTheme.success : AppTheme.error,
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
