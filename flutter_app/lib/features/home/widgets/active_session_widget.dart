import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class ActiveSessionWidget extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onEnded;
  const ActiveSessionWidget({super.key, required this.session, required this.onEnded});

  @override
  State<ActiveSessionWidget> createState() => _ActiveSessionWidgetState();
}

class _ActiveSessionWidgetState extends State<ActiveSessionWidget> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  bool _ending = false;

  DateTime get _checkinTime => DateTime.parse(widget.session['checkin_time'] as String);
  String get _clubName => (widget.session['clubs'] as Map<String, dynamic>?)?['name'] as String? ?? 'Клуб';

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
  }

  void _updateElapsed() {
    if (!mounted) return;
    setState(() => _elapsed = DateTime.now().difference(_checkinTime));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}ч ${m.toString().padLeft(2, '0')}м';
    return '${m}м ${s.toString().padLeft(2, '0')}с';
  }

  Future<void> _endSession() async {
    setState(() => _ending = true);
    try {
      await SupabaseService().endSession(widget.session['id'] as String);
      widget.onEnded();
    } catch (e) {
      if (mounted) {
        // TODO: Localize error message — needs ref.lang() access or localization passed via constructor
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardGlow(color: AppTheme.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.5), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 8),
              // TODO: Localize — needs ref.lang() access or localization passed via constructor
              const Text('Активная сессия',
                  style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _ending ? null : _endSession,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(color: AppTheme.error.withValues(alpha: 0.2), blurRadius: 8)],
                  ),
                  child: _ending
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.error))
                      // TODO: Localize — needs ref.lang() access or localization passed via constructor
                      : const Text('Завершить',
                          style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_clubName,
              style: TextStyle(color: context.text1, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer_rounded, color: AppTheme.success.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
