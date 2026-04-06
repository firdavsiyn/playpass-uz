import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/club.dart';
import '../../../services/supabase_service.dart';
import '../../clubs/providers/favorites_provider.dart';

final _favoriteClubsProvider = FutureProvider<List<Club>>((ref) async {
  ref.watch(favoritesProvider); // rebuild when favorites change
  return SupabaseService().getFavoriteClubs();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(_favoriteClubsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Избранные клубы')),
      body: clubsAsync.when(
        data: (clubs) {
          if (clubs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 64, color: context.text3.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('Нет избранных клубов',
                        style: TextStyle(color: context.text3, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Нажмите на сердечко на карточке клуба',
                        style: TextStyle(color: context.text3, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: clubs.length,
            itemBuilder: (_, i) => _FavClubCard(club: clubs[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}

class _FavClubCard extends ConsumerWidget {
  final Club club;
  const _FavClubCard({required this.club});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/clubs/${club.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
          boxShadow: AppTheme.cardGlow(),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.primary.withValues(alpha: 0.2),
                  AppTheme.neonPurple.withValues(alpha: 0.1),
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sports_esports, color: AppTheme.primaryLight, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name,
                      style: TextStyle(
                          color: context.text1, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(club.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.text3, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite_rounded, color: AppTheme.error),
              onPressed: () => ref.read(favoritesProvider.notifier).toggle(club.id),
            ),
          ],
        ),
      ),
    );
  }
}
