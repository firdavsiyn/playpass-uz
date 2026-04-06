import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

final leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return SupabaseService().getLeaderboard();
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Рейтинг игроков')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (players) {
          if (players.isEmpty) {
            return Center(
              child: Text('Пока нет данных', style: TextStyle(color: context.text3)),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(leaderboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Top 3 podium
                if (players.length >= 3) _Podium(players: players.take(3).toList()),
                const SizedBox(height: 20),

                // Rest of the list
                ...players.asMap().entries.skip(3).map((e) {
                  final i = e.key;
                  final p = e.value;
                  return _LeaderboardRow(rank: i + 1, player: p);
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  const _Podium({required this.players});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(child: _PodiumItem(player: players[1], rank: 2, height: 160,
              color: const Color(0xFFC0C0C0), emoji: '🥈')),
          const SizedBox(width: 8),
          // 1st place
          Expanded(child: _PodiumItem(player: players[0], rank: 1, height: 200,
              color: const Color(0xFFFFD700), emoji: '👑')),
          const SizedBox(width: 8),
          // 3rd place
          Expanded(child: _PodiumItem(player: players[2], rank: 3, height: 130,
              color: const Color(0xFFCD7F32), emoji: '🥉')),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final Map<String, dynamic> player;
  final int rank;
  final double height;
  final Color color;
  final String emoji;
  const _PodiumItem({required this.player, required this.rank, required this.height, required this.color, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: rank == 1 ? 28 : 22,
          backgroundColor: color.withValues(alpha: 0.3),
          backgroundImage: player['avatar_url'] != null ? NetworkImage(player['avatar_url'] as String) : null,
          child: player['avatar_url'] == null
              ? Text((player['name'] as String? ?? '?')[0].toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: rank == 1 ? 20 : 16))
              : null,
        ),
        const SizedBox(height: 6),
        Text(player['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.text1)),
        Text('${player['xp'] ?? 0} XP', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          height: height * 0.4,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Center(
            child: Text('#$rank', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> player;
  const _LeaderboardRow({required this.rank, required this.player});

  @override
  Widget build(BuildContext context) {
    final isMe = player['id'] == SupabaseService().currentUser?.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primary.withValues(alpha: 0.1) : context.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: isMe ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#$rank', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: isMe ? AppTheme.primary : context.text3)),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: context.bg,
            backgroundImage: player['avatar_url'] != null ? NetworkImage(player['avatar_url'] as String) : null,
            child: player['avatar_url'] == null
                ? Text((player['name'] as String? ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: context.text3, fontSize: 14))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player['name'] as String? ?? '', style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isMe ? AppTheme.primary : context.text1)),
                Text(_levelLabel(player['loyalty_level'] as String? ?? 'bronze'),
                    style: TextStyle(fontSize: 11, color: context.text3)),
              ],
            ),
          ),
          Text('${player['xp'] ?? 0} XP', style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: context.text2)),
        ],
      ),
    );
  }

  String _levelLabel(String level) => switch (level) {
    'diamond' => '💎 Diamond',
    'gold' => '🥇 Gold',
    'silver' => '🥈 Silver',
    _ => '🥉 Bronze',
  };
}
