import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/store/service_providers.dart';

final featuredAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return await tmdbService.getFeaturedAnime();
});

final popularAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return await tmdbService.getAnime();
});

final trendingAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return await tmdbService.getTrendingAnime();
});

final topRatedAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return await tmdbService.getTopRatedAnime();
});

final tvLogoProvider = FutureProvider.family<String?, int>((ref, id) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return tmdbService.getTVShowLogoUrl(id);
});

/// Eagerly fetches all logo URLs for the featured carousel in parallel.
/// Returns a map of TMDB id → logo URL so the carousel can do a direct
/// lookup without per-item async state.
final featuredAnimeLogosProvider = FutureProvider<Map<int, String?>>((ref) async {
  final featured = await ref.watch(featuredAnimeProvider.future);

  final logos = <int, String?>{};
  await Future.wait([
    for (final item in featured)
      () async {
        if (item is! Map) return;
        final id = item['id'] as int?;
        if (id == null) return;
        logos[id] = await ref.watch(tvLogoProvider(id).future);
      }(),
  ]);

  return logos;
});
