import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/watchlist_item.dart';
import '../services/watchlist_service.dart';

final watchlistServiceProvider = Provider<WatchlistService>((ref) {
  return WatchlistService();
});

class WatchlistNotifier extends StateNotifier<int> {
  WatchlistNotifier() : super(0);
  void refresh() => state++;
}

final watchlistRefreshProvider =
    StateNotifierProvider<WatchlistNotifier, int>((ref) {
  return WatchlistNotifier();
});

final watchlistProvider = Provider<List<WatchlistItem>>((ref) {
  ref.watch(watchlistRefreshProvider);
  final service = ref.watch(watchlistServiceProvider);
  return service.getAllItems();
});

final isInWatchlistProvider = Provider.family<bool, int>((ref, mediaId) {
  ref.watch(watchlistRefreshProvider);
  final service = ref.watch(watchlistServiceProvider);
  return service.isInWatchlist(mediaId);
});

final watchlistCountProvider = Provider<int>((ref) {
  ref.watch(watchlistRefreshProvider);
  final service = ref.watch(watchlistServiceProvider);
  return service.count;
});
