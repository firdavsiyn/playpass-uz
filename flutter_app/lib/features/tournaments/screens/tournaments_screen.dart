import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../models/tournament.dart';
import '../../../services/supabase_service.dart';

final tournamentsProvider = FutureProvider<List<Tournament>>((ref) {
  return SupabaseService().getTournaments();
});

class TournamentsScreen extends ConsumerWidget {
  const TournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tr(ref.watch(localeProvider));
    final data = ref.watch(tournamentsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t['tournaments_title'] ?? 'Турниры')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (tournaments) {
          if (tournaments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Text(t['tournaments_empty'] ?? 'Пока нет турниров',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          final upcoming = tournaments.where((t) => t.status == 'upcoming' || t.status == 'registration').toList();
          final ongoing = tournaments.where((t) => t.status == 'ongoing').toList();
          final finished = tournaments.where((t) => t.status == 'finished').toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(tournamentsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ongoing.isNotEmpty) ...[
                  _SectionTitle(t['tournaments_ongoing'] ?? 'Сейчас идут', Icons.play_circle, AppTheme.error),
                  ...ongoing.map((t) => _TournamentCard(tournament: t)),
                  const SizedBox(height: 16),
                ],
                if (upcoming.isNotEmpty) ...[
                  _SectionTitle(t['tournaments_upcoming'] ?? 'Предстоящие', Icons.schedule, AppTheme.primary),
                  ...upcoming.map((t) => _TournamentCard(tournament: t)),
                  const SizedBox(height: 16),
                ],
                if (finished.isNotEmpty) ...[
                  _SectionTitle(t['tournaments_finished'] ?? 'Завершённые', Icons.check_circle, AppTheme.success),
                  ...finished.map((t) => _TournamentCard(tournament: t)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  const _TournamentCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final spotsLeft = t.maxPlayers - t.participantCount;

    return GestureDetector(
      onTap: () => context.push('/tournaments/${t.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.status == 'ongoing' ? AppTheme.error.withValues(alpha: 0.5) : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with game badge
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Game icon
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sports_esports, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Row(children: [
                          _GameBadge(t.game),
                          const SizedBox(width: 8),
                          if (t.clubName != null)
                            Text(t.clubName!, style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                        ]),
                      ],
                    ),
                  ),
                  _StatusBadge(t.status),
                ],
              ),
            ),
            // Info row
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  _InfoChip(Icons.calendar_today, _formatDate(t.startsAt)),
                  const SizedBox(width: 12),
                  _InfoChip(Icons.people, '$spotsLeft мест'),
                  if (t.prizePool != null) ...[
                    const SizedBox(width: 12),
                    _InfoChip(Icons.emoji_events, t.prizePool!),
                  ],
                  const Spacer(),
                  if (t.isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('FREE', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)),
                    )
                  else
                    Text('${t.entryFee} UZS', style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.warning)),
                ],
              ),
            ),
            // Progress bar
            if (t.maxPlayers > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: t.participantCount / t.maxPlayers,
                    backgroundColor: AppTheme.border,
                    color: t.isFull ? AppTheme.error : AppTheme.primary,
                    minHeight: 4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    if (diff.inDays == 0) return 'Сегодня ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Завтра ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _GameBadge extends StatelessWidget {
  final String game;
  const _GameBadge(this.game);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(game, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _color => switch (status) {
    'ongoing' => AppTheme.error,
    'upcoming' || 'registration' => AppTheme.primary,
    'finished' => AppTheme.success,
    _ => AppTheme.textMuted,
  };

  String get _label => switch (status) {
    'ongoing' => 'LIVE',
    'upcoming' => 'Скоро',
    'registration' => 'Запись',
    'finished' => 'Готово',
    'cancelled' => 'Отмена',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: _color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
