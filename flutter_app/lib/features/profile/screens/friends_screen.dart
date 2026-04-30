import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/neon_shimmer.dart';
import '../../../services/supabase_service.dart';

final _friendsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService().getFriendsWithStatus();
});

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(_friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Друзья'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _showAddFriendDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(_friendsProvider);
          await ref.read(_friendsProvider.future);
        },
        child: friendsAsync.when(
          data: (friends) {
            if (friends.isEmpty) return _emptyState(context, ref);

            // Split into pending invites (status='pending', friend_id=me) and accepted
            final accepted = friends.where((f) => f['status'] == 'accepted').toList();
            final pending = friends.where((f) => f['status'] == 'pending').toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      'Запросы (${pending.length})',
                      style: TextStyle(
                        color: context.text2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ...pending.map((f) => _PendingTile(
                        friendship: f,
                        onResolved: () => ref.invalidate(_friendsProvider),
                      )),
                  const SizedBox(height: 16),
                ],
                if (accepted.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      'Друзья (${accepted.length})',
                      style: TextStyle(
                        color: context.text2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ...accepted.map((f) => _FriendTile(friend: f)),
                ],
              ],
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(5, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeonSkeletonCard(height: 64, borderRadius: 14),
              )),
            ),
          ),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 64, color: context.text3.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('Список друзей пуст', style: TextStyle(color: context.text2, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Добавь друзей по их коду из профиля',
                  style: TextStyle(color: context.text3, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showAddFriendDialog(context, ref),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Добавить друга'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    bool busy = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Добавить друга'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Введи реферальный код друга'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'НАПР: ALI-X7K',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: busy ? null : () async {
                final code = controller.text.trim().toUpperCase();
                if (code.isEmpty) return;
                setState(() => busy = true);
                final reason = await SupabaseService().sendFriendRequest(code);
                setState(() => busy = false);
                if (reason == null) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(_friendsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Запрос отправлен ✓')),
                  );
                } else {
                  setState(() => error = _reasonToText(reason));
                }
              },
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }

  String _reasonToText(String reason) {
    switch (reason) {
      case 'user_not_found': return 'Пользователь с таким кодом не найден';
      case 'cannot_self': return 'Нельзя добавить самого себя';
      case 'already_exists': return 'Запрос уже существует';
      default: return reason;
    }
  }
}

class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final name = friend['friend_name'] as String? ?? '?';
    final avatar = friend['friend_avatar'] as String?;
    final isOnline = friend['is_online'] as bool? ?? false;
    final clubName = friend['current_club_name'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: avatar == null
                      ? const LinearGradient(colors: [AppTheme.primary, AppTheme.neonCyan])
                      : null,
                  image: avatar != null
                      ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                      : null,
                ),
                child: avatar == null
                    ? Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: context.text1, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  isOnline && clubName != null ? '🎮 в $clubName' : 'не в сети',
                  style: TextStyle(
                    color: isOnline ? AppTheme.success : context.text3,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> friendship;
  final VoidCallback onResolved;
  const _PendingTile({required this.friendship, required this.onResolved});

  @override
  ConsumerState<_PendingTile> createState() => _PendingTileState();
}

class _PendingTileState extends ConsumerState<_PendingTile> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final id = widget.friendship['friendship_id'] as String;
    await SupabaseService().acceptFriendRequest(id);
    if (mounted) widget.onResolved();
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final id = widget.friendship['friendship_id'] as String;
    await SupabaseService().removeFriendship(id);
    if (mounted) widget.onResolved();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.friendship['friend_name'] as String? ?? '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppTheme.warning, AppTheme.primary]),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(color: context.text1, fontSize: 14, fontWeight: FontWeight.w700)),
                Text('хочет добавить тебя', style: TextStyle(color: context.text3, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: _busy ? null : _accept,
            icon: const Icon(Icons.check_rounded, color: AppTheme.success),
          ),
          IconButton(
            onPressed: _busy ? null : _decline,
            icon: const Icon(Icons.close_rounded, color: AppTheme.error),
          ),
        ],
      ),
    );
  }
}
