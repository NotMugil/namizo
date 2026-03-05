import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/providers/settingsproviders.dart';

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

List<dynamic> _applyAdultFilter(List<dynamic> items, bool hideAdultContent) {
  if (!hideAdultContent) return items;

  return items.where((item) {
    if (item is! Map) return true;

    final map = Map<String, dynamic>.from(item);
    final adultValue = map['adult'];
    final isAdult = adultValue == true || adultValue == 1;

    if (isAdult) return false;

    final genres = map['genre_ids'];
    if (genres is List) {
      final genreIds = genres.whereType<num>().map((e) => e.toInt()).toSet();
      if (genreIds.contains(12)) {
        return false;
      }
    }

    return true;
  }).toList(growable: false);
}

List<dynamic> _filterFeaturedByStatus(List<dynamic> items) {
  return items.where((item) {
    if (item is! Map) return false;
    final map = Map<String, dynamic>.from(item);
    final airing = map['airing'] == true;
    final status = (map['status']?.toString().toLowerCase() ?? '').trim();

    final isCompleted = status.contains('finished') ||
        status.contains('complete') ||
        status.contains('completed');
    return airing || isCompleted;
  }).toList(growable: false);
}

final featuredAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getFeaturedAnime();
  return _dedupeRowItems(
    _filterFeaturedByStatus(_applyAdultFilter(items, hideAdultContent)),
  );
});

final popularAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getAnime();
  return _dedupeRowItems(_applyAdultFilter(items, hideAdultContent));
});

final trendingAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getTrendingAnime();
  return _dedupeRowItems(_applyAdultFilter(items, hideAdultContent));
});

final topRatedAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getTopRatedAnime();
  return _dedupeRowItems(_applyAdultFilter(items, hideAdultContent));
});

final romanceAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getAnimeByGenre(
    18,
    sortBy: 'vote_average.desc',
    voteCountGte: 40,
  );
  return _dedupeRowItems(_applyAdultFilter(items, hideAdultContent));
});

final actionAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getAnimeByGenre(
    10759,
    sortBy: 'popularity.desc',
  );
  return _dedupeRowItems(_applyAdultFilter(items, hideAdultContent));
});

final adventureAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getAnimeByGenre(
    12,
    sortBy: 'first_air_date.desc',
  );
  return _dedupeRowItems(_applyAdultFilter(items, hideAdultContent));
});

final fantasyAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final tmdbService = ref.watch(kuroiruServiceProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final items = await tmdbService.getAnimeByGenre(
    10765,
    sortBy: 'vote_average.desc',
    voteCountGte: 40,
  );
  return _dedupeRowItems(_applyAdultFilter(items, hideAdultContent));
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
  return tmdbService.getTVShowNoTextPosterUrl(id);
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
