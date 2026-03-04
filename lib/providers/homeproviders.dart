import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/providers/serviceproviders.dart';

List<dynamic> _dedupeRowItems(List<dynamic> items) {
  final seenIds = <int>{};
  final seenTitles = <String>{};
  final deduped = <dynamic>[];

  for (final item in items) {
    if (item is! Map) continue;

    final id = (item['id'] as num?)?.toInt();
    final rawTitle = '${item['title'] ?? item['name'] ?? ''}'.trim().toLowerCase();

    if (id != null) {
      if (seenIds.contains(id)) continue;
      seenIds.add(id);
    } else {
      if (rawTitle.isNotEmpty && seenTitles.contains(rawTitle)) continue;
      if (rawTitle.isNotEmpty) {
        seenTitles.add(rawTitle);
      }
    }

    deduped.add(item);
  }

  return deduped;
}

final featuredAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(await tmdbService.getFeaturedAnime());
});

final popularAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(await tmdbService.getAnime());
});

final trendingAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(await tmdbService.getTrendingAnime());
});

final topRatedAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(await tmdbService.getTopRatedAnime());
});

final romanceAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(await tmdbService.getAnimeByGenre(
    18,
    sortBy: 'vote_average.desc',
    voteCountGte: 40,
  ));
});

final actionAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(
    await tmdbService.getAnimeByGenre(10759, sortBy: 'popularity.desc'),
  );
});

final adventureAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(await tmdbService.getAnimeByGenre(
    12,
    sortBy: 'first_air_date.desc',
  ));
});

final fantasyAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return _dedupeRowItems(await tmdbService.getAnimeByGenre(
    10765,
    sortBy: 'vote_average.desc',
    voteCountGte: 40,
  ));
});

final tvLogoProvider = FutureProvider.family<String?, int>((ref, id) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return tmdbService.getTVShowLogoUrl(id);
});

final tvBannerProvider = FutureProvider.family<String?, int>((ref, id) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return tmdbService.getTVShowBannerUrl(id);
});

final tvPosterProvider = FutureProvider.family<String?, int>((ref, id) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return tmdbService.getTVShowPosterUrl(id);
});

final tvCarouselImageProvider = FutureProvider.family<String?, int>((ref, id) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  return tmdbService.getTVShowCarouselImageUrl(id);
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

final featuredAnimeBannersProvider = FutureProvider<Map<int, String?>>((ref) async {
  final featured = await ref.watch(featuredAnimeProvider.future);

  final banners = <int, String?>{};
  await Future.wait([
    for (final item in featured)
      () async {
        if (item is! Map) return;
        final id = item['id'] as int?;
        if (id == null) return;
        banners[id] = await ref.watch(tvBannerProvider(id).future);
      }(),
  ]);

  return banners;
});

final featuredAnimePostersProvider = FutureProvider<Map<int, String?>>((ref) async {
  final featured = await ref.watch(featuredAnimeProvider.future);

  final posters = <int, String?>{};
  await Future.wait([
    for (final item in featured)
      () async {
        if (item is! Map) return;
        final id = item['id'] as int?;
        if (id == null) return;
        posters[id] = await ref.watch(tvCarouselImageProvider(id).future);
      }(),
  ]);

  return posters;
});
