import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

// Current page for pagination
final searchPageProvider = StateProvider<int>((ref) => 1);

// Language filter (null = all languages)
final searchLanguageFilterProvider = StateProvider<String?>((ref) => null);

// Sort option ('relevance', 'popularity', 'rating', 'year', 'title')
final searchSortProvider = StateProvider<String>((ref) => 'popularity');

// All accumulated search results (for pagination)
final accumulatedSearchResultsProvider = StateProvider<List<SearchResult>>((ref) => []);

// Total pages and results info
final searchMetadataProvider = StateProvider<({int totalPages, int totalResults})>((ref) {
  return (totalPages: 0, totalResults: 0);
});

// Search results provider with pagination
final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final page = ref.watch(searchPageProvider);
  final language = ref.watch(searchLanguageFilterProvider);
  final sortBy = ref.watch(searchSortProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  final aniList = ref.watch(aniListServiceProvider);
  final kuroiru = ref.watch(kuroiruServiceProvider);
  final normalizedSort = sortBy == 'relevance' ? null : sortBy;

  SearchResults results;
  try {
    results = query.isEmpty
        ? await aniList.browseAnime(
            page: page,
            language: language,
            sortBy: normalizedSort,
          )
        : await aniList.searchAnime(
            query,
            page: page,
            language: language,
            sortBy: normalizedSort,
          );
  } catch (_) {
    try {
      results = query.isEmpty
          ? await _browseFallback(
              kuroiru: kuroiru,
              page: page,
              sortBy: sortBy,
            )
          : await kuroiru.search(
              query,
              page: page,
              language: language,
              sortBy: normalizedSort,
            );
    } catch (_) {
      results = SearchResults(
        page: page,
        results: const [],
        totalPages: page == 1 ? 0 : page,
        totalResults: 0,
      );
    }
  }

  final filteredResults = hideAdultContent
      ? results.results.where((item) => !item.adult).toList(growable: false)
      : results.results;

  // Update metadata
  ref.read(searchMetadataProvider.notifier).state = (
    totalPages: results.totalPages,
    totalResults: results.totalResults,
  );

  // Accumulate results for infinite scroll
  if (page == 1) {
    ref.read(accumulatedSearchResultsProvider.notifier).state = filteredResults;
  } else {
    final accumulated = ref.read(accumulatedSearchResultsProvider);
    ref.read(accumulatedSearchResultsProvider.notifier).state = _dedupeById([
      ...accumulated,
      ...filteredResults,
    ]);
  }

  final accumulated = ref.read(accumulatedSearchResultsProvider);
  return SearchResults(
    page: page,
    results: accumulated,
    totalPages: results.totalPages,
    totalResults: results.totalResults,
  );
});

Future<SearchResults> _browseFallback({
  required dynamic kuroiru,
  required int page,
  required String sortBy,
}) async {
  if (page > 1) {
    return SearchResults(
      page: page,
      results: [],
      totalPages: 1,
      totalResults: 0,
    );
  }

  List<dynamic> rows;
  switch (sortBy) {
    case 'rating':
      rows = await kuroiru.getTopRatedAnime();
      break;
    case 'year':
      rows = await kuroiru.getTrendingAnime();
      break;
    case 'title':
      rows = await kuroiru.getAnime();
      break;
    case 'relevance':
    case 'popularity':
    default:
      rows = await kuroiru.getAnime();
      break;
  }

  var parsed = rows
      .whereType<Map>()
      .map((item) {
        try {
          return SearchResult.fromJson(Map<String, dynamic>.from(item));
        } catch (_) {
          return null;
        }
      })
      .whereType<SearchResult>()
      .toList(growable: false);

  if (sortBy == 'title') {
    parsed = List<SearchResult>.from(parsed)
      ..sort((a, b) {
        final aTitle = (a.title ?? a.name ?? '').toLowerCase();
        final bTitle = (b.title ?? b.name ?? '').toLowerCase();
        return aTitle.compareTo(bTitle);
      });
  }

  return SearchResults(
    page: page,
    results: parsed,
    totalPages: 1,
    totalResults: parsed.length,
  );
}

List<SearchResult> _dedupeById(List<SearchResult> input) {
  final seen = <int>{};
  final out = <SearchResult>[];
  for (final item in input) {
    if (!seen.add(item.id)) continue;
    out.add(item);
  }
  return out;
}
