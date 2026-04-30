import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

/// Compact "Friends in clubs right now" widget. Shows up to 3 avatar
/// stacks of online friends + a count, tapping opens friends screen.
final friendsOnlineProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService().getFriendsWithStatus();
});

class FriendsOnlineWidget extends ConsumerWidget {
  const FriendsOnlineWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsOnlineProvider);

    return friendsAsync.when(
      data: (all) {
        final accepted = all.where((f) => f['status'] == 'accepted').toList();
        final online = accepted.where((f) => f['is_online'] == true).toList();
        if (accepted.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/friends');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.success.withValues(alpha: 0.10),
                  AppTheme.neonCyan.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                // Stacked avatars
                _AvatarStack(friends: online.isEmpty ? accepted.take(3).toList() : online.take(3).toList()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online.isNotEmpty
                            ? '${online.length} ${_friendsWord(online.length)} в клубе'
                            : '${accepted.length} ${_friendsWord(accepted.length)}',
                        style: TextStyle(
                          color: context.text1,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        online.isNotEmpty
                            ? 'Присоединяйся 🎮'
                            : 'Никто сейчас не играет',
                        style: TextStyle(color: context.text3, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.text3, size: 20),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _friendsWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'друг';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'друга';
    return 'друзей';
  }
}

class _AvatarStack extends StatelessWidget {
  final List<Map<String, dynamic>> friends;
  const _AvatarStack({required this.friends});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32.0 + (friends.length - 1) * 18.0,
      height: 36,
      child: Stack(
        children: friends.asMap().entries.map((entry) {
          final i = entry.key;
          final f = entry.value;
          final name = f['friend_name'] as String? ?? '?';
          final avatar = f['friend_avatar'] as String?;
          final isOnline = f['is_online'] as bool? ?? false;

          return Positioned(
            left: i * 18.0,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.bg, width: 2),
                gradient: avatar == null
                    ? const LinearGradient(colors: [AppTheme.primary, AppTheme.neonCyan])
                    : null,
                image: avatar != null
                    ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                    : null,
                boxShadow: isOnline
                    ? [BoxShadow(color: AppTheme.success.withValues(alpha: 0.5), blurRadius: 6)]
                    : null,
              ),
              child: avatar == null
                  ? Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
