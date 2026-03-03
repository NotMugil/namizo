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

final romanceAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  final results = await tmdbService.getAnimeByGenre(
    18,
    sortBy: 'vote_average.desc',
    voteCountGte: 40,
  );

  return results.where((item) {
    if (item is! Map) return false;
    final title =
        '${item['name'] ?? item['title'] ?? ''}'.toLowerCase();
    final overview = '${item['overview'] ?? ''}'.toLowerCase();
    return title.contains('love') ||
        title.contains('romance') ||
        overview.contains('love') ||
        overview.contains('romance') ||
        overview.contains('relationship');
  }).toList();
});

final actionAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return await tmdbService.getAnimeByGenre(10759, sortBy: 'popularity.desc');
});

final adventureAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  final results = await tmdbService.getAnimeByGenre(
    10759,
    sortBy: 'first_air_date.desc',
  );

  return results.where((item) {
    if (item is! Map) return false;
    final title =
        '${item['name'] ?? item['title'] ?? ''}'.toLowerCase();
    final overview = '${item['overview'] ?? ''}'.toLowerCase();
    return title.contains('adventure') || overview.contains('adventure');
  }).toList();
});

final fantasyAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(tmdbServiceProvider);
  return await tmdbService.getAnimeByGenre(
    10765,
    sortBy: 'vote_average.desc',
    voteCountGte: 40,
  );
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
