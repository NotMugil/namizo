import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';

// ---------------------------------------------------------------------------
// Shared filter helpers
// ---------------------------------------------------------------------------

List<dynamic> _dedupeRowItems(List<dynamic> items) {
  final seenIds = <int>{};
  final seenTitles = <String>{};
  final deduped = <dynamic>[];

  for (final item in items) {
    if (item is! Map) continue;

    final id = (item['id'] as num?)?.toInt();
    final rawTitle =
        '${item['title'] ?? item['name'] ?? ''}'.trim().toLowerCase();

    if (id != null) {
      if (seenIds.contains(id)) continue;
      seenIds.add(id);
    } else {
      if (rawTitle.isNotEmpty && seenTitles.contains(rawTitle)) continue;
      if (rawTitle.isNotEmpty) seenTitles.add(rawTitle);
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
    if (adultValue == true || adultValue == 1) return false;
    final genres = map['genre_ids'];
    if (genres is List) {
      final genreIds =
          genres.whereType<num>().map((e) => e.toInt()).toSet();
      if (genreIds.contains(12)) return false;
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

// ---------------------------------------------------------------------------
// Curated list providers
// ---------------------------------------------------------------------------

final featuredAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(kuroiruServiceProvider);
  final hideAdult = ref.watch(hideAdultContentProvider);
  final items = await service.getFeaturedAnime();
  return _dedupeRowItems(
    _filterFeaturedByStatus(_applyAdultFilter(items, hideAdult)),
  );
});

final popularAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(kuroiruServiceProvider);
  final hideAdult = ref.watch(hideAdultContentProvider);
  return _dedupeRowItems(_applyAdultFilter(await service.getAnime(), hideAdult));
});

final trendingAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(kuroiruServiceProvider);
  final hideAdult = ref.watch(hideAdultContentProvider);
  return _dedupeRowItems(
    _applyAdultFilter(await service.getTrendingAnime(), hideAdult),
  );
});

final topRatedAnimeProvider = FutureProvider<List<dynamic>>((ref) async {
  final service = ref.watch(kuroiruServiceProvider);
  final hideAdult = ref.watch(hideAdultContentProvider);
  return _dedupeRowItems(
    _applyAdultFilter(await service.getTopRatedAnime(), hideAdult),
  );
});

// ---------------------------------------------------------------------------
// Genre providers — use shared factory to avoid repetition
// ---------------------------------------------------------------------------

FutureProvider<List<dynamic>> _genreProvider(
  int genreId, {
  String sortBy = 'popularity.desc',
  int? voteCountGte,
}) {
  return FutureProvider<List<dynamic>>((ref) async {
    final service = ref.watch(kuroiruServiceProvider);
    final hideAdult = ref.watch(hideAdultContentProvider);
    final items = await service.getAnimeByGenre(
      genreId,
      sortBy: sortBy,
      voteCountGte: voteCountGte ?? 20,
    );
    return _dedupeRowItems(_applyAdultFilter(items, hideAdult));
  });
}

final romanceAnimeProvider = _genreProvider(
  TmdbGenres.romance,
  sortBy: 'vote_average.desc',
  voteCountGte: 40,
);

final actionAnimeProvider = _genreProvider(
  TmdbGenres.action,
  sortBy: 'popularity.desc',
);

final adventureAnimeProvider = _genreProvider(
  TmdbGenres.adventure,
  sortBy: 'first_air_date.desc',
);

final fantasyAnimeProvider = _genreProvider(
  TmdbGenres.fantasy,
  sortBy: 'vote_average.desc',
  voteCountGte: 40,
);

// ---------------------------------------------------------------------------
// Per-item metadata providers (logo, banner, poster, carousel)
// ---------------------------------------------------------------------------

final tvLogoProvider = FutureProvider.family<String?, int>((ref, id) async {
  return ref.watch(kuroiruServiceProvider).getTVShowLogoUrl(id);
});

final tvBannerProvider = FutureProvider.family<String?, int>((ref, id) async {
  return ref.watch(kuroiruServiceProvider).getTVShowBannerUrl(id);
});

final tvPosterProvider = FutureProvider.family<String?, int>((ref, id) async {
  return ref.watch(kuroiruServiceProvider).getTVShowPosterUrl(id);
});

final tvCarouselImageProvider =
    FutureProvider.family<String?, int>((ref, id) async {
  return ref.watch(kuroiruServiceProvider).getTVShowNoTextPosterUrl(id);
});

// ---------------------------------------------------------------------------
// Eager bulk-fetch providers for the featured carousel
// ---------------------------------------------------------------------------

/// Helper: fetches a map of id → value for every item in [featuredAnimeProvider].
Future<Map<int, String?>> _fetchFeaturedMap(
  Ref ref,
  Future<String?> Function(int id) fetcher,
) async {
  final featured = await ref.watch(featuredAnimeProvider.future);
  final result = <int, String?>{};
  await Future.wait([
    for (final item in featured)
      () async {
        if (item is! Map) return;
        final id = item['id'] as int?;
        if (id == null) return;
        result[id] = await fetcher(id);
      }(),
  ]);
  return result;
}

final featuredAnimeLogosProvider =
    FutureProvider<Map<int, String?>>((ref) async {
  return _fetchFeaturedMap(
    ref,
    (id) => ref.watch(tvLogoProvider(id).future),
  );
});

final featuredAnimeBannersProvider =
    FutureProvider<Map<int, String?>>((ref) async {
  return _fetchFeaturedMap(
    ref,
    (id) => ref.watch(tvBannerProvider(id).future),
  );
});

final featuredAnimePostersProvider =
    FutureProvider<Map<int, String?>>((ref) async {
  return _fetchFeaturedMap(
    ref,
    (id) => ref.watch(tvCarouselImageProvider(id).future),
  );
});
