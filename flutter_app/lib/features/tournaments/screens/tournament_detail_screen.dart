import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/tournament.dart';
import '../../../services/supabase_service.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> {
  final _svc = SupabaseService();
  Tournament? _tournament;
  List<Map<String, dynamic>> _participants = [];
  bool _isRegistered = false;
  bool _loading = true;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _svc.getTournamentById(widget.tournamentId),
        _svc.getTournamentParticipants(widget.tournamentId),
        _svc.isRegisteredForTournament(widget.tournamentId),
      ]);
      if (!mounted) return;
      setState(() {
        _tournament = results[0] as Tournament;
        _participants = results[1] as List<Map<String, dynamic>>;
        _isRegistered = results[2] as bool;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleRegistration() async {
    setState(() => _registering = true);
    try {
      if (_isRegistered) {
        await _svc.unregisterFromTournament(widget.tournamentId);
      } else {
        await _svc.registerForTournament(widget.tournamentId);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
    if (mounted) setState(() => _registering = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final t = _tournament;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Турнир не найден')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.title),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Game & Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports_esports, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(t.game, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (t.clubName != null) Text(t.clubName!, style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 20),

          // Info cards
          Row(
            children: [
              _InfoCard('Дата', _formatDate(t.startsAt), Icons.calendar_today),
              const SizedBox(width: 12),
              _InfoCard('Участники', '${t.participantCount}/${t.maxPlayers}', Icons.people),
              const SizedBox(width: 12),
              _InfoCard('Приз', t.prizePool ?? 'Нет', Icons.emoji_events),
            ],
          ),
          const SizedBox(height: 20),

          // Description
          if (t.description != null) ...[
            const Text('Описание', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(t.description!, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
          ],

          // Rules
          if (t.rules != null) ...[
            const Text('Правила', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(t.rules!, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
            ),
            const SizedBox(height: 20),
          ],

          // Participants
          Text('Участники (${_participants.length})', style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          if (_participants.isEmpty)
            const Text('Пока никто не записался', style: TextStyle(color: AppTheme.textMuted))
          else
            ..._participants.map((p) {
              final user = p['users'] as Map<String, dynamic>?;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      backgroundImage: user?['avatar_url'] != null ? NetworkImage(user!['avatar_url']) : null,
                      child: user?['avatar_url'] == null
                          ? Text((user?['name'] as String? ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(user?['name'] ?? 'Игрок',
                          style: const TextStyle(color: AppTheme.textPrimary)),
                    ),
                    if (p['team_name'] != null)
                      Text(p['team_name'], style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    if (p['status'] == 'winner')
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.emoji_events, color: AppTheme.warning, size: 20),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: t.isRegistrationOpen ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _registering || t.isFull && !_isRegistered ? null : _toggleRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRegistered ? AppTheme.error : AppTheme.primary,
              minimumSize: const Size.fromHeight(52),
            ),
            child: _registering
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isRegistered ? 'Отменить запись' : (t.isFull ? 'Мест нет' : 'Записаться'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ) : null,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
