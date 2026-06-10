import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/club.dart';
import '../../../core/theme/app_theme.dart';
import 'occupancy_badge.dart';

/// Bottom sheet shown when a map marker is tapped
class ClubMapBottomSheet extends StatelessWidget {
  final Club club;
  final int occupancy;
  const ClubMapBottomSheet({super.key, required this.club, this.occupancy = 0});

  void _navigate(BuildContext context) async {
    if (club.lat == null || club.lon == null) return;
    final url = Uri.parse(
      'https://yandex.ru/maps/?rtext=~${club.lat},${club.lon}&rtt=auto',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _call() async {
    if (club.contactPhone == null) return;
    final cleaned = club.contactPhone!.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: context.text3.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Club info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: club.thumbnail != null
                    ? CachedNetworkImage(
                        imageUrl: club.thumbnail!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: context.surface,
                        child: Icon(Icons.sports_esports,
                            color: context.text3, size: 32),
                      ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
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
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (club.tier == 'vip')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.tierVip.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('VIP',
                                style: TextStyle(
                                    color: AppTheme.tierVip,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
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
                          child: Text(club.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.text3, fontSize: 12)),
                        ),
                      ],
                    ),
                    if (club.contactPhone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 13, color: context.text3),
                          const SizedBox(width: 2),
                          Text(club.contactPhone!,
                              style: TextStyle(
                                  color: context.text2, fontSize: 12)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppTheme.tierVip),
                        const SizedBox(width: 2),
                        Text(club.rating.toStringAsFixed(1),
                            style:
                                TextStyle(color: context.text2, fontSize: 12)),
                        const SizedBox(width: 10),
                        Icon(Icons.computer, size: 14, color: context.text3),
                        const SizedBox(width: 2),
                        Text('${club.pcCount} ПК',
                            style:
                                TextStyle(color: context.text3, fontSize: 12)),
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
                    if (club.pcCount > 0) ...[
                      const SizedBox(height: 8),
                      OccupancyBadge(
                        current: occupancy,
                        capacity: club.pcCount,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Call button
              if (club.contactPhone != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _call,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Icon(Icons.phone_rounded, size: 22),
                    ),
                  ),
                ),
              // Navigate button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigate(context),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Поехали'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Details button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/clubs/${club.id}');
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Подробнее'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
