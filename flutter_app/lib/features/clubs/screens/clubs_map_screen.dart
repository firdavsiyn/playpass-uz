import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/club.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../widgets/yandex_map_widget.dart';
import '../widgets/club_map_bottom_sheet.dart';
import '../services/yandex_map_service.dart';
import '../../../core/widgets/branded_loader.dart';
import '../../../core/widgets/error_retry.dart';

// Own providers so data is independent from clubs_list filters
final _mapClubsProvider = FutureProvider<List<Club>>((ref) {
  return SupabaseService().getActiveClubs();
});

final _mapOccupancyProvider = FutureProvider<Map<String, int>>((ref) {
  return SupabaseService().getAllClubsOccupancy();
});

class ClubsMapScreen extends ConsumerStatefulWidget {
  const ClubsMapScreen({super.key});

  @override
  ConsumerState<ClubsMapScreen> createState() => _ClubsMapScreenState();
}

class _ClubsMapScreenState extends ConsumerState<ClubsMapScreen> {
  void _showClubSheet(String clubId) {
    final clubs = ref.read(_mapClubsProvider).valueOrNull ?? [];
    final match = clubs.where((c) => c.id == clubId);
    if (match.isEmpty) return;
    final club = match.first;
    final occ = ref.read(_mapOccupancyProvider).valueOrNull;
    final count = occ?[club.id] ?? 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => ClubMapBottomSheet(club: club, occupancy: count),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(_mapClubsProvider);
    final occ = ref.watch(_mapOccupancyProvider).valueOrNull;

    return Scaffold(
      body: clubsAsync.when(
        loading: () => Container(
          color: context.bg,
          child: const BrandedLoader(label: 'Загружаем клубы...'),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(
            backgroundColor: context.bg,
            title: Text(ref.lang('clubs_map_title')),
          ),
          body: ErrorRetry(
            error: e,
            onRetry: () => ref.invalidate(_mapClubsProvider),
          ),
        ),
        data: (clubs) {
          if (clubs.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: context.bg,
                title: Text(ref.lang('clubs_map_title')),
              ),
              body: Center(
                child:
                    Text('Нет клубов', style: TextStyle(color: context.text3)),
              ),
            );
          }
          return Stack(
            children: [
              // Full-screen Yandex Map
              YandexMapWidget(
                clubs: clubs,
                occupancy: occ,
                onMarkerTapped: _showClubSheet,
              ),

              // Top bar overlay
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    // Back button
                    _OverlayButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    // Title
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.card.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          '${clubs.length} клубов на карте',
                          style: TextStyle(
                            color: context.text1,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // My location button
                    _OverlayButton(
                      icon: Icons.my_location_rounded,
                      onTap: () async {
                        YandexMapService.locateUser();
                        // Check after a delay for error (geolocation is async)
                        await Future.delayed(const Duration(seconds: 2));
                        if (!context.mounted) return;
                        final err = YandexMapService.getLastLocateError();
                        if (err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Не удалось определить местоположение: $err'),
                              backgroundColor: AppTheme.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Semi-transparent overlay button for the map
class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _OverlayButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: context.text1, size: 22),
      ),
    );
  }
}
