import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

final lfgPostsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, game) {
  return SupabaseService().getLfgPosts(game: game);
});

final selectedLfgGameProvider = StateProvider<String?>((ref) => null);

class LfgScreen extends ConsumerWidget {
  const LfgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGame = ref.watch(selectedLfgGameProvider);
    final data = ref.watch(lfgPostsProvider(selectedGame));
    final games = ['CS2', 'Dota 2', 'Valorant', 'PUBG', 'Apex Legends'];

    return Scaffold(
      appBar: AppBar(title: const Text('Поиск тиммейтов')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePost(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Найти команду'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          // Game filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _GameChip(
                    label: 'Все',
                    selected: selectedGame == null,
                    onTap: () => ref
                        .read(selectedLfgGameProvider.notifier)
                        .state = null),
                ...games.map((g) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _GameChip(
                          label: g,
                          selected: selectedGame == g,
                          onTap: () => ref
                              .read(selectedLfgGameProvider.notifier)
                              .state = g),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),

          // Posts
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (posts) {
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: context.text3),
                        const SizedBox(height: 12),
                        Text('Нет активных запросов',
                            style: TextStyle(color: context.text2)),
                        const SizedBox(height: 4),
                        Text('Создайте первый!',
                            style:
                                TextStyle(color: context.text3, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(lfgPostsProvider(selectedGame).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => _LfgCard(post: posts[i], ref: ref),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePost(BuildContext context, WidgetRef ref) {
    String game = 'CS2';
    final msgCtrl = TextEditingController();
    int playersNeeded = 1;
    bool micRequired = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Найти тиммейтов',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.text1)),
              const SizedBox(height: 16),
              Text('Игра',
                  style: TextStyle(fontSize: 13, color: context.text2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['CS2', 'Dota 2', 'Valorant', 'PUBG', 'Apex Legends']
                    .map((g) => GestureDetector(
                          onTap: () => setState(() => game = g),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: game == g ? AppTheme.primary : context.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: game == g
                                      ? AppTheme.primary
                                      : context.border),
                            ),
                            child: Text(g,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: game == g
                                        ? Colors.white
                                        : context.text2)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Нужно игроков: ',
                      style: TextStyle(color: context.text2)),
                  IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          color: context.text3),
                      onPressed: playersNeeded > 1
                          ? () => setState(() => playersNeeded--)
                          : null),
                  Text('$playersNeeded',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.text1)),
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppTheme.primary),
                      onPressed: playersNeeded < 9
                          ? () => setState(() => playersNeeded++)
                          : null),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                      value: micRequired,
                      onChanged: (v) =>
                          setState(() => micRequired = v ?? false),
                      activeColor: AppTheme.primary),
                  Text('Микрофон обязателен',
                      style: TextStyle(color: context.text2)),
                ],
              ),
              TextField(
                controller: msgCtrl,
                style: TextStyle(color: context.text1),
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Сообщение',
                    hintText: 'Ищу в рейт, ранг Faceit 7+...'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await SupabaseService().createLfgPost(
                    game: game,
                    playersNeeded: playersNeeded,
                    message: msgCtrl.text.trim().isEmpty
                        ? null
                        : msgCtrl.text.trim(),
                    micRequired: micRequired,
                  );
                  ref.invalidate(
                      lfgPostsProvider(ref.read(selectedLfgGameProvider)));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Опубликовать'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GameChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : context.cardDark,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? AppTheme.primary : context.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : context.text2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _LfgCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final WidgetRef ref;
  const _LfgCard({required this.post, required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = post['users'] as Map<String, dynamic>?;
    final club = post['clubs'] as Map<String, dynamic>?;
    final expiresAt = DateTime.parse(post['expires_at'] as String);
    final timeLeft = expiresAt.difference(DateTime.now());
    final isOwn = post['user_id'] == SupabaseService().currentUser?.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                backgroundImage: user?['avatar_url'] != null
                    ? NetworkImage(user!['avatar_url'])
                    : null,
                child: user?['avatar_url'] == null
                    ? Text((user?['name'] as String? ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['name'] ?? 'Игрок',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: context.text1)),
                    if (club != null)
                      Text(club['name'] as String? ?? '',
                          style: TextStyle(fontSize: 12, color: context.text3)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(post['game'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Message
          if (post['message'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(post['message'] as String,
                  style: TextStyle(color: context.text2, height: 1.4)),
            ),

          // Info row
          Row(
            children: [
              _InfoBadge(Icons.people, '+${post['players_needed']}'),
              const SizedBox(width: 8),
              if (post['mic_required'] == true) ...[
                _InfoBadge(Icons.mic, 'Микрофон'),
                const SizedBox(width: 8),
              ],
              _InfoBadge(
                  Icons.timer_outlined,
                  timeLeft.inMinutes > 60
                      ? '${timeLeft.inHours}ч'
                      : '${timeLeft.inMinutes}м'),
              const Spacer(),
              if (!isOwn)
                ElevatedButton(
                  onPressed: () async {
                    await SupabaseService().respondToLfg(post['id'] as String);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Запрос отправлен!'),
                            backgroundColor: AppTheme.success),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Присоединиться',
                      style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBadge(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.text3),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: context.text2)),
        ],
      ),
    );
  }
}
