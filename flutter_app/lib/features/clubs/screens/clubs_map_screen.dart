import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../services/supabase_service.dart';

final clubsMapProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return SupabaseService().getClubsWithCoordinates();
});

class ClubsMapScreen extends ConsumerStatefulWidget {
  const ClubsMapScreen({super.key});

  @override
  ConsumerState<ClubsMapScreen> createState() => _ClubsMapScreenState();
}

class _ClubsMapScreenState extends ConsumerState<ClubsMapScreen> {
  String? _selectedClubId;
  final _scrollController = ScrollController();

  // Tashkent bounds (with padding)
  static const _minLat = 41.20;
  static const _maxLat = 41.39;
  static const _minLon = 69.15;
  static const _maxLon = 69.39;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Offset _geoToScreen(double lat, double lon, Size size) {
    final x = (lon - _minLon) / (_maxLon - _minLon) * size.width;
    final y = (1 - (lat - _minLat) / (_maxLat - _minLat)) * size.height;
    return Offset(x.clamp(16, size.width - 16), y.clamp(16, size.height - 16));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(clubsMapProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.lang('clubs_map_title'))),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (clubs) {
          if (clubs.isEmpty) {
            return Center(child: Text('Нет клубов', style: TextStyle(color: context.text3)));
          }

          final selected = _selectedClubId != null
              ? clubs.cast<Map<String, dynamic>?>().firstWhere(
                  (c) => c!['id'] == _selectedClubId,
                  orElse: () => null)
              : null;

          return Column(
            children: [
              // Map area
              Expanded(
                flex: 5,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onTapUp: (details) {
                        // Find nearest club to tap
                        double minDist = 40;
                        String? nearest;
                        for (final c in clubs) {
                          final lat = (c['latitude'] as num?)?.toDouble();
                          final lon = (c['longitude'] as num?)?.toDouble();
                          if (lat == null || lon == null) continue;
                          final pos = _geoToScreen(lat, lon, size);
                          final dist = (pos - details.localPosition).distance;
                          if (dist < minDist) {
                            minDist = dist;
                            nearest = c['id'] as String?;
                          }
                        }
                        setState(() => _selectedClubId = nearest);
                        if (nearest != null) {
                          final idx = clubs.indexWhere((c) => c['id'] == nearest);
                          if (idx >= 0) {
                            _scrollController.animateTo(
                              idx * 76.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.03),
                              context.bg,
                            ],
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Map grid
                            CustomPaint(size: size, painter: _MapGridPainter(context)),
                            // City label
                            Positioned(
                              top: 12, left: 16,
                              child: Row(
                                children: [
                                  const Text('📍', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text('Ташкент',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.text1)),
                                ],
                              ),
                            ),
                            // Club pins
                            ...clubs.map((c) {
                              final lat = (c['latitude'] as num?)?.toDouble();
                              final lon = (c['longitude'] as num?)?.toDouble();
                              if (lat == null || lon == null) return const SizedBox.shrink();
                              final pos = _geoToScreen(lat, lon, size);
                              final isSelected = c['id'] == _selectedClubId;
                              final pinSize = isSelected ? 20.0 : 12.0;
                              return Positioned(
                                left: pos.dx - pinSize / 2,
                                top: pos.dy - pinSize / 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedClubId = c['id'] as String?);
                                    final idx = clubs.indexWhere((cl) => cl['id'] == c['id']);
                                    if (idx >= 0) {
                                      _scrollController.animateTo(
                                        idx * 76.0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: pinSize,
                                    height: pinSize,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.white54,
                                        width: isSelected ? 2.5 : 1.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                                          : [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // Selected club tooltip
                            if (selected != null) _buildTooltip(selected, size, context),
                            // Legend
                            Positioned(
                              bottom: 12, right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: context.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: context.border),
                                ),
                                child: Text('${clubs.length} клубов',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Divider
              Container(height: 1, color: context.border),
              // Club list
              Expanded(
                flex: 4,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: clubs.length,
                  itemExtent: 76,
                  itemBuilder: (context, i) {
                    final c = clubs[i];
                    final isSelected = c['id'] == _selectedClubId;
                    return Material(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/clubs/${c['id']}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary.withValues(alpha: 0.2)
                                      : AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.sports_esports, color: AppTheme.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(c['name'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isSelected ? AppTheme.primary : context.text1,
                                      )),
                                    const SizedBox(height: 2),
                                    Text(c['address'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: context.text3)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: context.text3, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTooltip(Map<String, dynamic> club, Size mapSize, BuildContext context) {
    final lat = (club['latitude'] as num?)?.toDouble() ?? 0;
    final lon = (club['longitude'] as num?)?.toDouble() ?? 0;
    final pos = _geoToScreen(lat, lon, mapSize);
    final showAbove = pos.dy > 80;
    final tooltipWidth = 180.0;
    final left = (pos.dx - tooltipWidth / 2).clamp(8.0, mapSize.width - tooltipWidth - 8);

    return Positioned(
      left: left,
      top: showAbove ? pos.dy - 60 : pos.dy + 20,
      child: GestureDetector(
        onTap: () => context.push('/clubs/${club['id']}'),
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(club['name'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.text1)),
                    Text(club['address'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: context.text3)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final BuildContext context;
  _MapGridPainter(this.context);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;

    // Subtle grid
    for (var x = 0.0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw "roads" — curved lines to simulate a map
    final roadPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.08)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Horizontal "roads"
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.25 + i * 0.25);
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * 0.3, y - 20 + i * 15, size.width * 0.5, y + 5)
        ..quadraticBezierTo(size.width * 0.7, y + 25 - i * 10, size.width, y - 10);
      canvas.drawPath(path, roadPaint);
    }

    // Vertical "roads"
    for (var i = 0; i < 2; i++) {
      final x = size.width * (0.35 + i * 0.3);
      final path = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(x + 15 - i * 20, size.height * 0.4, x - 10, size.height * 0.6)
        ..quadraticBezierTo(x - 5 + i * 15, size.height * 0.8, x + 10, size.height);
      canvas.drawPath(path, roadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
