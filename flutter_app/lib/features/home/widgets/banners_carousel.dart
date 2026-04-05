import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

final bannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService().getActiveBanners();
});

class BannersCarousel extends ConsumerStatefulWidget {
  const BannersCarousel({super.key});

  @override
  ConsumerState<BannersCarousel> createState() => _BannersCarouselState();
}

class _BannersCarouselState extends ConsumerState<BannersCarousel> {
  final _pageController = PageController(viewportFraction: 0.92);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider);

    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            itemCount: banners.length,
            itemBuilder: (_, i) => _BannerCard(banner: banners[i]),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final title = banner['title'] as String? ?? '';
    final description = banner['description'] as String? ?? '';
    final imageUrl = banner['image_url'] as String?;
    final actionUrl = banner['action_url'] as String?;
    final bgColor = banner['bg_color'] as String?;

    final color = bgColor != null
        ? Color(int.parse(bgColor.replaceFirst('#', '0xFF')))
        : AppTheme.primary;

    return GestureDetector(
      onTap: actionUrl != null ? () async {
        final url = Uri.tryParse(actionUrl);
        if (url != null && await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: imageUrl == null ? LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          image: imageUrl != null ? DecorationImage(
            image: CachedNetworkImageProvider(imageUrl),
            fit: BoxFit.cover,
          ) : null,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: imageUrl != null ? LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (title.isNotEmpty)
                Text(title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
