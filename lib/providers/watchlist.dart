import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/utils/status.dart';
import 'package:namizo/models/user/watchlist_item.dart';
import '../services/watchlist.dart';

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
  final localItems = service.getAllItems();

  final byId = <int, WatchlistItem>{
    for (final item in localItems) item.id: item,
  };

  final aniListTracked = ref.watch(aniListTrackedAnimeProvider).valueOrNull ??
      const <Map<String, dynamic>>[];

  for (final row in aniListTracked) {
    final id = (row['id'] as num?)?.toInt();
    if (id == null || id <= 0 || byId.containsKey(id)) continue;

    final title =
        (row['title'] ?? row['name'] ?? '').toString().trim();
    if (title.isEmpty) continue;

    DateTime addedAt = DateTime.fromMillisecondsSinceEpoch(0);
    final updatedAtRaw = row['updated_at']?.toString();
    if (updatedAtRaw != null && updatedAtRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(updatedAtRaw);
      if (parsed != null) {
        addedAt = parsed;
      }
    }

    byId[id] = WatchlistItem(
      id: id,
      title: title,
      posterPath: row['poster_path']?.toString(),
      backdropPath: row['backdrop_path']?.toString(),
      mediaType: (row['media_type']?.toString() ?? 'tv'),
      addedAt: addedAt,
      voteAverage: (row['vote_average'] as num?)?.toDouble(),
      releaseDate: row['first_air_date']?.toString(),
      overview: row['overview']?.toString(),
    );
  }

  final merged = byId.values.toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return merged;
});

final isInWatchlistProvider = Provider.family<bool, int>((ref, mediaId) {
  final watchlist = ref.watch(watchlistProvider);
  return watchlist.any((item) => item.id == mediaId);
});

final watchlistCountProvider = Provider<int>((ref) {
  final watchlist = ref.watch(watchlistProvider);
  return watchlist.length;
});


final watchlistStatusByIdProvider = Provider<Map<int, String>>((ref) {
  final tracked = ref.watch(aniListTrackedAnimeProvider).valueOrNull ??
      const <Map<String, dynamic>>[];

  final byId = <int, String>{};
  for (final row in tracked) {
    final id = (row['id'] as num?)?.toInt();
    if (id == null || id <= 0) continue;
    byId[id] = normalizeWatchStatus(row['status']?.toString());
  }
  return byId;
});

final watchlistGroupedByStatusProvider =
    Provider<Map<String, List<WatchlistItem>>>((ref) {
  final items = ref.watch(watchlistProvider);
  final statusById = ref.watch(watchlistStatusByIdProvider);

  final grouped = <String, List<WatchlistItem>>{
    'WATCHING': <WatchlistItem>[],
    'PLANNING': <WatchlistItem>[],
    'PAUSED': <WatchlistItem>[],
    'DROPPED': <WatchlistItem>[],
    'COMPLETED': <WatchlistItem>[],
  };

  for (final item in items) {
    final status = statusById[item.id] ?? 'WATCHING';
    grouped.putIfAbsent(status, () => <WatchlistItem>[]).add(item);
  }

  return grouped;
});
