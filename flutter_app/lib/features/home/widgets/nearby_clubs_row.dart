import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/club.dart';
import '../../../core/theme/app_theme.dart';

class NearbyClubsRow extends StatelessWidget {
  final AsyncValue<List<Club>> clubsAsync;
  const NearbyClubsRow({super.key, required this.clubsAsync});

  @override
  Widget build(BuildContext context) {
    return clubsAsync.when(
      data: (clubs) => clubs.isEmpty
          ? const Text('Клубы не найдены', style: TextStyle(color: AppTheme.textMuted))
          : SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: clubs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _ClubCard(club: clubs[i]),
              ),
            ),
      loading: () => SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const _ClubCardSkeleton(),
        ),
      ),
      error: (_, __) => const Text('Ошибка загрузки', style: TextStyle(color: AppTheme.error)),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final Club club;
  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/clubs/${club.id}'),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
          boxShadow: AppTheme.cardGlow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: club.thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: club.thumbnail!,
                      height: 90,
                      width: 140,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 90,
                        color: AppTheme.bgSurface,
                        child: const Icon(Icons.image_outlined, color: AppTheme.textMuted),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 90,
                        color: AppTheme.bgSurface,
                        child: const Icon(Icons.sports_esports, color: AppTheme.textMuted),
                      ),
                    )
                  : Container(
                      height: 90,
                      color: AppTheme.bgSurface,
                      child: const Center(
                        child: Icon(Icons.sports_esports, color: AppTheme.textMuted, size: 32),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: club.isOpen ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        club.isOpen ? 'Открыт' : 'Закрыт',
                        style: TextStyle(
                          color: club.isOpen ? AppTheme.success : AppTheme.error,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star, size: 12, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 2),
                      Text(
                        club.rating.toStringAsFixed(1),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
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

class _ClubCardSkeleton extends StatelessWidget {
  const _ClubCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
