import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/services/kuroiru.dart';
import 'package:namizo/services/anilist.dart';
import 'package:namizo/services/streaming.dart';
import 'package:namizo/services/history.dart';
import 'package:namizo/core/cache/cache_service.dart';

// Cache service provider
final cacheServiceProvider = Provider((ref) {
  final cache = CacheService();
  // Note: init() must be called before use, handled in main.dart
  return cache;
});

// Service Providers
final kuroiruServiceProvider = Provider<KuroiruService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return KuroiruService(cache);
});

final aniListServiceProvider = Provider((ref) => AniListService());

final aniListAccountRefreshProvider = StateProvider<int>((ref) => 0);

final aniListViewerProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(aniListAccountRefreshProvider);
  final service = ref.watch(aniListServiceProvider);
  return service.getViewerProfile();
});

final aniListActivitiesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    ref.watch(aniListAccountRefreshProvider);
    final service = ref.watch(aniListServiceProvider);
    return service.getViewerActivities();
  },
);

final aniListPlanningProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    ref.watch(aniListAccountRefreshProvider);
    final service = ref.watch(aniListServiceProvider);
    return service.getViewerPlanningAnime();
  },
);

final aniListTrackedIdsProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(aniListAccountRefreshProvider);
  final service = ref.watch(aniListServiceProvider);
  return service.getViewerTrackedAnimeIds();
});

final aniListTrackedAnimeProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    ref.watch(aniListAccountRefreshProvider);
    final service = ref.watch(aniListServiceProvider);
    return service.getViewerTrackedAnime();
  },
);
 
// Streaming service provider (anime direct + embed fallback)
final streamingServiceProvider = Provider((ref) => StreamingService());

final watchHistoryServiceProvider = Provider((ref) => WatchHistoryService());
