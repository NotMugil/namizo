import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/models/search_result.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';

// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

// Current page for pagination
final searchPageProvider = StateProvider<int>((ref) => 1);

// Language filter (null = all languages)
final searchLanguageFilterProvider = StateProvider<String?>((ref) => null);

// Sort option (null = default, 'popularity', 'title', 'year')
final searchSortProvider = StateProvider<String?>((ref) => null);

// All accumulated search results (for pagination)
final accumulatedSearchResultsProvider = StateProvider<List<SearchResult>>((ref) => []);

// Total pages and results info
final searchMetadataProvider = StateProvider<({int totalPages, int totalResults})>((ref) {
  return (totalPages: 0, totalResults: 0);
});

// Search results provider with pagination
final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) {
    ref.read(accumulatedSearchResultsProvider.notifier).state = [];
    ref.read(searchMetadataProvider.notifier).state = (totalPages: 0, totalResults: 0);
    return const SearchResults(
      page: 0,
      results: [],
      totalPages: 0,
      totalResults: 0,
    );
  }

  final page = ref.watch(searchPageProvider);
  final language = ref.watch(searchLanguageFilterProvider);
  final sortBy = ref.watch(searchSortProvider);
  final hideAdultContent = ref.watch(hideAdultContentProvider);
  
  final aniList = ref.watch(aniListServiceProvider);
  final results = await aniList.searchAnime(
    query,
    page: page,
    language: language,
    sortBy: sortBy,
  );
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
    ref.read(accumulatedSearchResultsProvider.notifier).state = [...accumulated, ...filteredResults];
  }
  
  final accumulated = ref.read(accumulatedSearchResultsProvider);
  return SearchResults(
    page: page,
    results: accumulated,
    totalPages: results.totalPages,
    totalResults: results.totalResults,
  );
});
