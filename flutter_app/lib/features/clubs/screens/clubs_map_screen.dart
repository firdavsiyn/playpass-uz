import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../services/supabase_service.dart';

final clubsMapProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return SupabaseService().getClubsWithCoordinates();
});

class ClubsMapScreen extends ConsumerWidget {
  const ClubsMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tr(ref.watch(localeProvider));
    final data = ref.watch(clubsMapProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t['clubs_map_title'] ?? 'Карта клубов')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (clubs) {
          if (clubs.isEmpty) {
            return const Center(child: Text('Нет клубов', style: TextStyle(color: AppTheme.textMuted)));
          }

          return Column(
            children: [
              // Map placeholder with club pins
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Stack(
                    children: [
                      // Grid background to simulate map
                      CustomPaint(
                        size: Size.infinite,
                        painter: _MapGridPainter(),
                      ),
                      // City label
                      const Positioned(
                        top: 16, left: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📍 Ташкент', style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            Text('Интерактивная карта скоро', style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      // Club pins scattered
                      ...clubs.asMap().entries.map((e) {
                        final i = e.key;
                        final c = e.value;
                        final xPos = 40.0 + (i % 4) * 80.0 + (i * 23 % 50);
                        final yPos = 60.0 + (i ~/ 4) * 90.0 + (i * 17 % 40);
                        return Positioned(
                          left: xPos.clamp(20, MediaQuery.of(context).size.width - 60),
                          top: yPos.clamp(50, 300),
                          child: GestureDetector(
                            onTap: () => context.push('/clubs/${c['id']}'),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 8)],
                                  ),
                                  child: const Icon(Icons.sports_esports, color: Colors.white, size: 18),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgDark.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    c['name'] as String? ?? '',
                                    style: const TextStyle(fontSize: 9, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      // Legend
                      Positioned(
                        bottom: 16, right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.bgDark.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${clubs.length} клубов', style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Club list below map
              Expanded(
                flex: 2,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: clubs.length,
                  itemBuilder: (context, i) {
                    final c = clubs[i];
                    return ListTile(
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: c['logo_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(c['logo_url'], fit: BoxFit.cover))
                            : const Icon(Icons.sports_esports, color: AppTheme.primary),
                      ),
                      title: Text(c['name'] ?? '', style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      subtitle: Text(c['address'] ?? '', style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                      onTap: () => context.push('/clubs/${c['id']}'),
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
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
