import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/club.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/widgets/neon_shimmer.dart';

class NearbyClubsRow extends ConsumerWidget {
  final AsyncValue<List<Club>> clubsAsync;
  const NearbyClubsRow({super.key, required this.clubsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return clubsAsync.when(
      data: (clubs) => clubs.isEmpty
          ? Text(ref.lang('nearby.not_found'),
              style: TextStyle(color: context.text3))
          : SizedBox(
              height: 175,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: clubs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _ClubCard(club: clubs[i]),
              ),
            ),
      loading: () => SizedBox(
        height: 175,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const _ClubCardSkeleton(),
        ),
      ),
      error: (_, __) => Text(ref.lang('nearby.error'),
          style: const TextStyle(color: AppTheme.error)),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final Club club;
  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final statusColor = club.isOpen ? AppTheme.success : AppTheme.error;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/clubs/${club.id}');
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo with overlay badges
            Stack(
              children: [
                Hero(
                  tag: 'club_image_${club.id}',
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: club.thumbnail != null
                        ? CachedNetworkImage(
                            imageUrl: club.thumbnail!,
                            height: 100,
                            width: 150,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 100,
                              color: context.surface,
                              child: const Center(
                                child: Icon(Icons.image_outlined,
                                    color: AppTheme.textMuted, size: 24),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primary.withValues(alpha: 0.15),
                                    AppTheme.neonCyan.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Center(
                                child: Icon(Icons.sports_esports_rounded,
                                    color: AppTheme.textMuted, size: 28),
                              ),
                            ),
                          )
                        : Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primary.withValues(alpha: 0.15),
                                  AppTheme.neonCyan.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.sports_esports_rounded,
                                  color: AppTheme.textMuted, size: 32),
                            ),
                          ),
                  ),
                ),

                // Gradient overlay at bottom of image
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          context.card.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status badge (top-right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: statusColor, blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          club.isOpen ? 'LIVE' : 'OFF',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tier badge (top-left) if VIP
                if (club.tier == 'vip')
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.tierVip.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.tierVip.withValues(alpha: 0.4)),
                      ),
                      child: const Text('VIP',
                          style: TextStyle(
                            color: AppTheme.tierVip,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
                  ),
              ],
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.text1,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 14, color: AppTheme.tierVip),
                      const SizedBox(width: 2),
                      Text(
                        club.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: context.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.computer_rounded,
                          size: 12, color: context.text3),
                      const SizedBox(width: 3),
                      Text(
                        '${club.pcCount}',
                        style: TextStyle(color: context.text3, fontSize: 11),
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
    return NeonShimmer(
      borderRadius: 16,
      child: Container(
        width: 150,
        height: 175,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.04)),
        ),
      ),
    );
  }
}
