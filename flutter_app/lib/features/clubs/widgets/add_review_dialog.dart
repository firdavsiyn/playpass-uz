import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../../../services/achievement_service.dart';

class AddReviewDialog extends StatefulWidget {
  final String clubId;
  final String clubName;
  final VoidCallback onSubmitted;

  const AddReviewDialog({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.onSubmitted,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  int _rating = 0;
  final _textController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите оценку')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await SupabaseService().addReview(
        clubId: widget.clubId,
        rating: _rating,
        text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отзыв опубликован!')),
        );
        // Check achievements in background
        AchievementService().checkAndUnlock().then((names) {
          if (names.isNotEmpty && context.mounted) {
            AchievementService.showUnlockNotifications(context, names);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            widget.clubName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Оцените ваш визит',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),

          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: starIndex <= _rating
                        ? const Color(0xFFFBBF24)
                        : AppTheme.textMuted,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Text field
          TextField(
            controller: _textController,
            maxLines: 3,
            maxLength: 500,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Расскажите о вашем опыте (необязательно)',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppTheme.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _rating > 0
                    ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12)]
                    : [],
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Отправить отзыв'),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
