import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/models/user/watch_history.dart';
import 'package:namizo/providers/services.dart';

/// Increment to trigger a reload of watch history providers.
/// Call `ref.read(watchHistoryRefreshProvider.notifier).refresh()` after
/// updating progress (e.g. from the player screen).
class _WatchHistoryRefreshNotifier extends StateNotifier<int> {
  _WatchHistoryRefreshNotifier() : super(0);
  void refresh() => state++;
}

final watchHistoryRefreshProvider =
    StateNotifierProvider<_WatchHistoryRefreshNotifier, int>(
      (ref) => _WatchHistoryRefreshNotifier(),
    );

final watchHistoryProvider = FutureProvider<List<WatchHistory>>((ref) async {
  ref.watch(watchHistoryRefreshProvider);
  final service = ref.watch(watchHistoryServiceProvider);
  await service.init();
  return service.getAllHistory();
});

final continueWatchingProvider = FutureProvider<List<WatchHistory>>((ref) async {
  ref.watch(watchHistoryRefreshProvider);
  final service = ref.watch(watchHistoryServiceProvider);
  await service.init();
  return service.getContinueWatching();
});

final mediaHistoryProvider =
    FutureProvider.family<WatchHistory?, int>((ref, tmdbId) async {
  ref.watch(watchHistoryRefreshProvider);
  final service = ref.watch(watchHistoryServiceProvider);
  await service.init();
  return service.getHistory(tmdbId);
});
