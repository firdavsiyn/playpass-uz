import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = await SupabaseService().getFavoriteClubIds();
      state = ids.toSet();
    } catch (_) {}
  }

  bool isFavorite(String clubId) => state.contains(clubId);

  Future<void> toggle(String clubId) async {
    final was = state.contains(clubId);
    // Optimistic update
    state = was ? ({...state}..remove(clubId)) : {...state, clubId};
    try {
      if (was) {
        await SupabaseService().removeFavorite(clubId);
      } else {
        await SupabaseService().addFavorite(clubId);
      }
    } catch (_) {
      // Revert
      state = was ? {...state, clubId} : ({...state}..remove(clubId));
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (_) => FavoritesNotifier(),
);
