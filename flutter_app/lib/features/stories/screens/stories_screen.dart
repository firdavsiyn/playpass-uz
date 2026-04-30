import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../models/story.dart';
import '../../../services/supabase_service.dart';

final storiesProvider = FutureProvider<List<Story>>((ref) {
  return SupabaseService().getStories();
});

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tr(ref.watch(localeProvider));
    final data = ref.watch(storiesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t['stories_title'] ?? 'Новости')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (stories) {
          if (stories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: context.text3),
                  const SizedBox(height: 12),
                  Text(t['stories_empty'] ?? 'Пока нет новостей',
                      style: TextStyle(color: context.text2)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(storiesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stories.length,
              itemBuilder: (context, i) => _StoryCard(story: stories[i]),
            ),
          );
        },
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final Story story;
  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (story.imageUrl != null)
            CachedNetworkImage(
              imageUrl: story.imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 180,
                color: context.card,
                child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    if (story.clubLogo != null)
                      CircleAvatar(
                        radius: 14,
                        backgroundImage:
                            CachedNetworkImageProvider(story.clubLogo!),
                      )
                    else
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: story.authorType == 'platform'
                            ? AppTheme.primary.withValues(alpha: 0.2)
                            : AppTheme.warning.withValues(alpha: 0.2),
                        child: Icon(
                          story.authorType == 'platform'
                              ? Icons.star
                              : Icons.storefront,
                          size: 14,
                          color: story.authorType == 'platform'
                              ? AppTheme.primary
                              : AppTheme.warning,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        story.clubName ?? 'PlayPass',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.text1),
                      ),
                    ),
                    Text(story.timeAgo,
                        style: TextStyle(fontSize: 12, color: context.text3)),
                    if (story.isPinned) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.push_pin,
                          size: 14, color: AppTheme.warning),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(story.title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.text1,
                        height: 1.3)),

                // Body
                if (story.body != null) ...[
                  const SizedBox(height: 8),
                  Text(story.body!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: context.text2, height: 1.5)),
                ],

                // Link button
                if (story.linkUrl != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(story.linkUrl!)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(story.linkLabel ?? 'Подробнее',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward,
                              size: 14, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],

                // Footer
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.visibility_outlined,
                        size: 14, color: context.text3),
                    const SizedBox(width: 4),
                    Text('${story.viewsCount}',
                        style: TextStyle(fontSize: 12, color: context.text3)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal story bubbles for home screen
class StoryBubbles extends ConsumerWidget {
  const StoryBubbles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storiesProvider);
    return data.when(
      loading: () => const SizedBox(height: 90),
      error: (_, __) => const SizedBox.shrink(),
      data: (stories) {
        if (stories.isEmpty) return const SizedBox.shrink();
        final recent = stories.take(10).toList();
        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            itemBuilder: (context, i) {
              final s = recent[i];
              return GestureDetector(
                onTap: () {
                  SupabaseService().markStoryViewed(s.id);
                  _showStoryViewer(context, recent, i, ref);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                s.isViewed ? context.text3 : AppTheme.primary,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 27,
                          backgroundColor: context.card,
                          backgroundImage: s.clubLogo != null
                              ? CachedNetworkImageProvider(s.clubLogo!)
                              : null,
                          child: s.clubLogo == null
                              ? Icon(
                                  s.authorType == 'platform'
                                      ? Icons.star
                                      : Icons.storefront,
                                  size: 20,
                                  color: AppTheme.primary)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 64,
                        child: Text(
                          s.clubName ?? 'PlayPass',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: s.isViewed ? context.text3 : context.text1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showStoryViewer(
      BuildContext context, List<Story> stories, int index, WidgetRef ref) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _StoryViewerDialog(stories: stories, initialIndex: index),
    );
  }
}

class _StoryViewerDialog extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  const _StoryViewerDialog({required this.stories, required this.initialIndex});

  @override
  State<_StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends State<_StoryViewerDialog> {
  late PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if (d.primaryVelocity != null && d.primaryVelocity! > 300)
          Navigator.pop(context);
      },
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.stories.length,
        onPageChanged: (i) {
          setState(() => _current = i);
          SupabaseService().markStoryViewed(widget.stories[i].id);
        },
        itemBuilder: (context, i) {
          final s = widget.stories[i];
          return SafeArea(
            child: Column(
              children: [
                // Progress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      widget.stories.length.clamp(0, 10),
                      (j) => Container(
                            width: _current == j ? 16 : 6,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: _current == j
                                  ? AppTheme.primary
                                  : context.text3,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )),
                ),
                const SizedBox(height: 8),
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (s.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: s.imageUrl!,
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        if (s.body != null) ...[
                          const SizedBox(height: 12),
                          Text(s.body!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white70,
                                  height: 1.5)),
                        ],
                        const SizedBox(height: 16),
                        Text(s.clubName ?? 'PlayPass',
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
