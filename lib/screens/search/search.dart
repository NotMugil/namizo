import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/providers/search.dart';
import 'package:namizo/screens/search/search_result_card.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialFeedKey});

  final String? initialQuery;
  final String? initialFeedKey;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const Map<String, String> _feedQueries = <String, String>{
    'popular': 'popular anime',
    'trending': 'trending anime',
    'topRated': 'top rated anime',
    'romance': 'romance anime',
    'action': 'action anime',
    'adventure': 'adventure anime',
    'fantasy': 'fantasy anime',
  };

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _typeFilter = 'all';
  String _scoreFilter = 'all';
  String _yearFilter = 'all';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialSearch());
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialFeedKey != widget.initialFeedKey) {
      _applyInitialSearch();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final sortBy = ref.watch(searchSortProvider);
    final metadata = ref.watch(searchMetadataProvider);
    final searchAsync = ref.watch(searchResultsProvider);
    final allResults = searchAsync.valueOrNull?.results ?? const <SearchResult>[];
    final filteredResults = _applyFilters(allResults);
    final hasQuery = query.trim().isNotEmpty;
    final isLoadingFirstPage = searchAsync.isLoading && allResults.isEmpty;
    final isLoadingMore = searchAsync.isLoading && allResults.isNotEmpty;

    return Scaffold(
      backgroundColor: NamizoTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: _buildSearchBar(context, sortBy),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(
                    label: _typeFilterLabel(_typeFilter),
                    isActive: _typeFilter != 'all',
                    onTap: () => _showTypeFilterSheet(context),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    label: _scoreFilterLabel(_scoreFilter),
                    isActive: _scoreFilter != 'all',
                    onTap: () => _showScoreFilterSheet(context),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    label: _yearFilterLabel(_yearFilter),
                    isActive: _yearFilter != 'all',
                    onTap: () => _showYearFilterSheet(context),
                  ),
                  if (_typeFilter != 'all' ||
                      _scoreFilter != 'all' ||
                      _yearFilter != 'all') ...[
                    const SizedBox(width: 8),
                    _filterChip(
                      label: 'Reset',
                      isActive: false,
                      onTap: () {
                        setState(() {
                          _typeFilter = 'all';
                          _scoreFilter = 'all';
                          _yearFilter = 'all';
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    hasQuery ? '${filteredResults.length} shown' : 'Discover',
                    style: const TextStyle(
                      color: NamizoTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (metadata.totalResults > 0)
                    Text(
                      '${metadata.totalResults} total',
                      style: const TextStyle(
                        color: NamizoTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (isLoadingFirstPage) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: NamizoTheme.primary,
                      ),
                    );
                  }
                  if (searchAsync.hasError && allResults.isEmpty) {
                    return _SearchError(
                      onRetry: () => ref.invalidate(searchResultsProvider),
                    );
                  }
                  if (filteredResults.isEmpty) {
                    if (!hasQuery) return const _SearchPrompt();
                    return const _NoSearchResults();
                  }

                  return RefreshIndicator(
                    color: NamizoTheme.primary,
                    onRefresh: () async => _runSearch(query),
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filteredResults.length + (isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= filteredResults.length) {
                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: NamizoTheme.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return SearchResultCard(media: filteredResults[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, String sortBy) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search anime',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _runSearch('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {});
              _searchDebounce?.cancel();
              _searchDebounce = Timer(
                const Duration(milliseconds: 420),
                () => _runSearch(value),
              );
            },
            onSubmitted: _runSearch,
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          tooltip: 'Sort',
          onSelected: _setSort,
          color: const Color(0xFF1A1A1A),
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'relevance',
              child: Text('Relevance'),
            ),
            PopupMenuItem<String>(
              value: 'popularity',
              child: Text('Popularity'),
            ),
            PopupMenuItem<String>(
              value: 'rating',
              child: Text('Rating'),
            ),
            PopupMenuItem<String>(
              value: 'year',
              child: Text('Newest'),
            ),
            PopupMenuItem<String>(
              value: 'title',
              child: Text('Title A-Z'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PhosphorIcon(
                  PhosphorIconsRegular.sortAscending,
                  color: NamizoTheme.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _sortLabel(sortBy),
                  style: const TextStyle(
                    color: NamizoTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      shape: const StadiumBorder(),
      side: BorderSide(
        color: isActive
            ? NamizoTheme.primary.withValues(alpha: 0.42)
            : Colors.white.withValues(alpha: 0.14),
      ),
      backgroundColor: isActive
          ? NamizoTheme.primary.withValues(alpha: 0.2)
          : const Color(0xFF1A1A1A),
      labelStyle: TextStyle(
        color: isActive ? NamizoTheme.textPrimary : NamizoTheme.textSecondary,
        fontSize: 12,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  Future<void> _showTypeFilterSheet(BuildContext context) async {
    final value = await _showFilterSheet(
      context,
      title: 'Type',
      currentValue: _typeFilter,
      options: const {
        'all': 'All types',
        'tv': 'TV',
        'movie': 'Movie',
        'ova': 'OVA',
        'ona': 'ONA',
      },
    );
    if (value == null) return;
    setState(() => _typeFilter = value);
  }

  Future<void> _showScoreFilterSheet(BuildContext context) async {
    final value = await _showFilterSheet(
      context,
      title: 'Score',
      currentValue: _scoreFilter,
      options: const {
        'all': 'All scores',
        'gte7': '7.0 and above',
        'gte8': '8.0 and above',
        'gte9': '9.0 and above',
      },
    );
    if (value == null) return;
    setState(() => _scoreFilter = value);
  }

  Future<void> _showYearFilterSheet(BuildContext context) async {
    final value = await _showFilterSheet(
      context,
      title: 'Year',
      currentValue: _yearFilter,
      options: const {
        'all': 'All years',
        'y2020': '2020+',
        'y2015': '2015+',
        'older': 'Before 2015',
      },
    );
    if (value == null) return;
    setState(() => _yearFilter = value);
  }

  Future<String?> _showFilterSheet(
    BuildContext context, {
    required String title,
    required String currentValue,
    required Map<String, String> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF101216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: NamizoTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              for (final entry in options.entries)
                ListTile(
                  onTap: () => Navigator.of(context).pop(entry.key),
                  leading: Icon(
                    entry.key == currentValue
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: entry.key == currentValue
                        ? NamizoTheme.primary
                        : NamizoTheme.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      color: entry.key == currentValue
                          ? NamizoTheme.textPrimary
                          : NamizoTheme.textSecondary,
                      fontWeight: entry.key == currentValue
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
            ],
          ),
        );
      },
    );
  }

  String _sortLabel(String sortBy) {
    switch (sortBy) {
      case 'relevance':
        return 'Relevance';
      case 'popularity':
        return 'Popular';
      case 'rating':
        return 'Rating';
      case 'year':
        return 'Newest';
      case 'title':
        return 'A-Z';
      default:
        return 'Sort';
    }
  }

  String _typeFilterLabel(String value) {
    switch (value) {
      case 'tv':
        return 'TV';
      case 'movie':
        return 'Movie';
      case 'ova':
        return 'OVA';
      case 'ona':
        return 'ONA';
      default:
        return 'Type';
    }
  }

  String _scoreFilterLabel(String value) {
    switch (value) {
      case 'gte7':
        return 'Score 7+';
      case 'gte8':
        return 'Score 8+';
      case 'gte9':
        return 'Score 9+';
      default:
        return 'Score';
    }
  }

  String _yearFilterLabel(String value) {
    switch (value) {
      case 'y2020':
        return '2020+';
      case 'y2015':
        return '2015+';
      case 'older':
        return '< 2015';
      default:
        return 'Year';
    }
  }

  void _setSort(String value) {
    if (value == ref.read(searchSortProvider)) return;
    ref.read(searchSortProvider.notifier).state = value;
    _runSearch(ref.read(searchQueryProvider));
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return;
    }
    if (position.pixels < position.maxScrollExtent - 280) {
      return;
    }

    final metadata = ref.read(searchMetadataProvider);
    final page = ref.read(searchPageProvider);
    final isLoading = ref.read(searchResultsProvider).isLoading;
    if (isLoading) return;
    if (metadata.totalPages <= 0 || page >= metadata.totalPages) return;

    ref.read(searchPageProvider.notifier).state = page + 1;
  }

  void _applyInitialSearch() {
    final directQuery = widget.initialQuery?.trim();
    final query = (directQuery != null && directQuery.isNotEmpty)
        ? directQuery
        : _feedQueries[widget.initialFeedKey] ?? '';
    _searchController.text = query;
    _runSearch(query);
  }

  void _runSearch(String rawQuery) {
    final query = rawQuery.trim();
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(accumulatedSearchResultsProvider.notifier).state = [];
    ref.read(searchMetadataProvider.notifier).state = (
      totalPages: 0,
      totalResults: 0,
    );
    ref.read(searchQueryProvider.notifier).state = query;
    ref.invalidate(searchResultsProvider);
  }

  List<SearchResult> _applyFilters(List<SearchResult> input) {
    return input.where((item) {
      if (_typeFilter != 'all' &&
          item.mediaType.trim().toLowerCase() != _typeFilter) {
        return false;
      }

      final score = item.voteAverage ?? 0;
      if (_scoreFilter == 'gte7' && score < 7) return false;
      if (_scoreFilter == 'gte8' && score < 8) return false;
      if (_scoreFilter == 'gte9' && score < 9) return false;

      final year = _extractYear(item);
      if (_yearFilter == 'y2020' && (year == null || year < 2020)) return false;
      if (_yearFilter == 'y2015' && (year == null || year < 2015)) return false;
      if (_yearFilter == 'older' && (year == null || year >= 2015)) return false;

      return true;
    }).toList(growable: false);
  }

  int? _extractYear(SearchResult item) {
    final raw = item.releaseDate ?? item.firstAirDate;
    if (raw == null || raw.length < 4) return null;
    return int.tryParse(raw.substring(0, 4));
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            color: Colors.white.withValues(alpha: 0.3),
            size: 54,
          ),
          const SizedBox(height: 12),
          Text(
            'No discover results right now',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a search query or pull to refresh.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: NamizoTheme.textSecondary,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            'No titles found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: NamizoTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another keyword or clear some filters.',
            style: TextStyle(
              color: NamizoTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: NamizoTheme.error, size: 34),
          const SizedBox(height: 10),
          const Text(
            'Search failed',
            style: TextStyle(
              color: NamizoTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
