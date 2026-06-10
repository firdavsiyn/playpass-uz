import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/branded_loader.dart';
import '../../../services/supabase_service.dart';

final playerStatsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final svc = SupabaseService();
  final userId = svc.currentUser!.id;
  final res = await svc.getPlayerProfiles(userId);
  return res;
});

class PlayerStatsScreen extends ConsumerWidget {
  const PlayerStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(playerStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика игрока'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddProfileDialog(context, ref),
          ),
        ],
      ),
      body: data.when(
        loading: () => const BrandedLoader(),
        error: (e, _) => Center(child: Text('$e')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_esports_outlined,
                      size: 64, color: context.text3),
                  const SizedBox(height: 12),
                  Text('Добавьте свой игровой профиль',
                      style: TextStyle(color: context.text2)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddProfileDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Добавить профиль'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(playerStatsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: profiles
                  .map((p) => _GameProfileCard(profile: p, ref: ref))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context, WidgetRef ref) {
    final games = [
      'CS2',
      'Dota 2',
      'Valorant',
      'PUBG',
      'Fortnite',
      'Apex Legends',
      'League of Legends',
      'FIFA'
    ];
    String selectedGame = 'CS2';
    final nicknameCtrl = TextEditingController();
    final rankCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Добавить игровой профиль',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.text1)),
              const SizedBox(height: 20),

              // Game selector
              Text('Игра',
                  style: TextStyle(fontSize: 13, color: context.text2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: games
                    .map((g) => GestureDetector(
                          onTap: () => setState(() => selectedGame = g),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedGame == g
                                  ? AppTheme.primary
                                  : context.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: selectedGame == g
                                      ? AppTheme.primary
                                      : context.border),
                            ),
                            child: Text(g,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: selectedGame == g
                                        ? Colors.white
                                        : context.text2,
                                    fontWeight: selectedGame == g
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nicknameCtrl,
                style: TextStyle(color: context.text1),
                decoration: const InputDecoration(
                    labelText: 'Никнейм', hintText: 'Ваш ник в игре'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rankCtrl,
                style: TextStyle(color: context.text1),
                decoration: const InputDecoration(
                    labelText: 'Ранг', hintText: 'Global Elite, Immortal...'),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () async {
                  if (nicknameCtrl.text.trim().isEmpty) return;
                  await SupabaseService().savePlayerProfile(
                    game: selectedGame,
                    nickname: nicknameCtrl.text.trim(),
                    rank: rankCtrl.text.trim().isEmpty
                        ? null
                        : rankCtrl.text.trim(),
                  );
                  ref.invalidate(playerStatsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final WidgetRef ref;
  const _GameProfileCard({required this.profile, required this.ref});

  static const _gameColors = {
    'CS2': Color(0xFFE8A82E),
    'Dota 2': Color(0xFFDB2727),
    'Valorant': Color(0xFFFF4655),
    'PUBG': Color(0xFFF2A900),
    'Fortnite': Color(0xFF9D4DFF),
    'Apex Legends': Color(0xFFDA292A),
    'League of Legends': Color(0xFF0BC6E3),
    'FIFA': Color(0xFF326295),
  };

  static const _gameIcons = {
    'CS2': '',
    'Dota 2': '',
    'Valorant': '',
    'PUBG': '',
    'Fortnite': '',
    'Apex Legends': '',
    'League of Legends': '',
    'FIFA': '',
  };

  @override
  Widget build(BuildContext context) {
    final game = profile['game'] as String? ?? '';
    final color = _gameColors[game] ?? AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(_gameIcons[game] ?? '',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      Text(profile['nickname'] as String? ?? '',
                          style: TextStyle(fontSize: 14, color: context.text2)),
                    ],
                  ),
                ),
                if (profile['rank'] != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(profile['rank'] as String,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatItem(
                    'Часов', '${profile['hours_played'] ?? 0}', Icons.timer),
                _StatItem('K/D', profile['kd_ratio']?.toString() ?? '—',
                    Icons.track_changes),
                _StatItem(
                    'Winrate',
                    profile['winrate'] != null ? '${profile['winrate']}%' : '—',
                    Icons.emoji_events),
              ],
            ),
          ),

          // Delete button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GestureDetector(
              onTap: () async {
                await SupabaseService()
                    .deletePlayerProfile(profile['id'] as String);
                ref.invalidate(playerStatsProvider);
              },
              child: const Text('Удалить профиль',
                  style: TextStyle(fontSize: 12, color: AppTheme.error)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: context.text3),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.text1)),
          Text(label, style: TextStyle(fontSize: 11, color: context.text3)),
        ],
      ),
    );
  }
}
