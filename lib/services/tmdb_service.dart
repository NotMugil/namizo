import 'package:dio/dio.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/models/search_result.dart';
import 'package:namizo/models/season_info.dart';
import 'package:namizo/services/cache_service.dart';

class TmdbService {
  final Dio _dio;
  final CacheService _cache;

  TmdbService(this._cache)
    : _dio = Dio(
        BaseOptions(
          baseUrl: tmdbBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'namizo/1.0 (compatible; +https://example.com)',
          },
          queryParameters: {'api_key': tmdbApiKey},
        ),
      );

  /// Anime-only search (Japanese TV animation entries).
  Future<SearchResults> search(
    String query, {
    int page = 1,
    String? language,
    String? sortBy,
  }) async {
    final normalizedQuery = _normalizeSearchText(query);
    final normalizedSort = sortBy == 'rating' ? 'popularity' : sortBy;
    final cacheKey =
        'search_anime_${normalizedQuery}_${page}_${normalizedSort ?? 'relevance'}';

    if (normalizedQuery.isEmpty) {
      return const SearchResults(
        page: 0,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }

    if (language != null && language.isNotEmpty && language != 'ja') {
      return const SearchResults(
        page: 1,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }

    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final results = SearchResults.fromJson(cached);
      return results.copyWith(
        results: _postProcessSearchResults(
          results.results,
          query: normalizedQuery,
          sortBy: normalizedSort,
        ),
      );
    }

    try {
      final response = await _dio.get(
        '/3/search/tv',
        queryParameters: {
          'query': normalizedQuery,
          'page': page,
          'include_adult': false,
          'language': 'en',
        },
      );

      final parsed = _parseTypedSearchResults(response.data['results']);
      final processed = _postProcessSearchResults(
        parsed,
        query: normalizedQuery,
        sortBy: normalizedSort,
      );

      final merged = SearchResults(
        page: page,
        results: processed,
        totalPages: (response.data['total_pages'] as num?)?.toInt() ?? 0,
        totalResults: (response.data['total_results'] as num?)?.toInt() ?? 0,
      );

      await _cache.set(cacheKey, merged.toJson(), ttl: CacheService.mediumCache);
      return merged;
    } catch (e) {
      throw Exception('Failed to search anime: $e');
    }
  }

  List<SearchResult> _parseTypedSearchResults(dynamic rawResults) {
    if (rawResults is! List) return const [];

    final parsed = <SearchResult>[];
    for (final item in rawResults) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      json['media_type'] = 'tv';
      parsed.add(SearchResult.fromJson(json));
    }
    return parsed;
  }

  List<SearchResult> _postProcessSearchResults(
    List<SearchResult> results, {
    required String query,
    String? sortBy,
  }) {
    var processed = List<SearchResult>.from(results);

    processed = processed
        .where((item) => item.mediaType == 'tv')
        .where((item) => (item.originalLanguage ?? '').toLowerCase() == 'ja')
        .toList();

    final seen = <String>{};
    processed = processed.where((item) => seen.add('tv_${item.id}')).toList();

    switch (sortBy) {
      case 'popularity':
      case 'rating':
        processed.sort((a, b) {
          final ratingCompare = (b.voteAverage ?? 0).compareTo(
            a.voteAverage ?? 0,
          );
          if (ratingCompare != 0) return ratingCompare;
          return _compareByYearDesc(a, b);
        });
        break;
      case 'title':
        processed.sort((a, b) {
          final titleA = _normalizeSearchText(a.title ?? a.name ?? '');
          final titleB = _normalizeSearchText(b.title ?? b.name ?? '');
          return titleA.compareTo(titleB);
        });
        break;
      case 'year':
        processed.sort(_compareByYearDesc);
        break;
      default:
        processed.sort((a, b) {
          final scoreA = _relevanceScore(a, query);
          final scoreB = _relevanceScore(b, query);
          final relevanceCompare = scoreB.compareTo(scoreA);
          if (relevanceCompare != 0) return relevanceCompare;
          return (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0);
        });
    }

    return processed;
  }

  int _compareByYearDesc(SearchResult a, SearchResult b) {
    final yearA = _extractYear(a) ?? 0;
    final yearB = _extractYear(b) ?? 0;
    final yearCompare = yearB.compareTo(yearA);
    if (yearCompare != 0) return yearCompare;
    return (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0);
  }

  int _relevanceScore(SearchResult item, String query) {
    final title = _normalizeSearchText(item.title ?? item.name ?? '');
    final overview = _normalizeSearchText(item.overview ?? '');
    if (title.isEmpty) return -1;

    var score = 0;
    if (title == query) score += 1000;
    if (title.startsWith(query)) score += 400;
    if (title.contains(query)) score += 250;

    final tokens = query.split(' ').where((token) => token.isNotEmpty).toList();
    for (final token in tokens) {
      if (title.contains(token)) score += 70;
      if (title.startsWith(token)) score += 20;
      if (overview.contains(token)) score += 10;
    }

    score += ((item.voteAverage ?? 0) * 8).round();
    final year = _extractYear(item);
    if (year != null) {
      score += year ~/ 100;
    }

    return score;
  }

  int? _extractYear(SearchResult result) {
    final date = result.firstAirDate ?? result.releaseDate;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  String _normalizeSearchText(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<SeriesInfo> getSeriesInfo(int showId) async {
    final cacheKey = 'series_info_$showId';

    final cached = await _cache.get<SeriesInfo>(
      cacheKey,
      (json) => SeriesInfo.fromJson(json),
    );
    if (cached != null) return cached;

    try {
      final response = await _dio.get('/3/tv/$showId');
      await _cache.set(cacheKey, response.data, ttl: CacheService.longCache);
      return SeriesInfo.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get anime series info: $e');
    }
  }

  Future<SeasonData> getSeasonInfo(int showId, int seasonNumber) async {
    final cacheKey = 'season_info_${showId}_$seasonNumber';

    final cached = await _cache.get<SeasonData>(
      cacheKey,
      (json) => SeasonData.fromJson(json),
    );
    if (cached != null) return cached;

    try {
      final response = await _dio.get('/3/tv/$showId/season/$seasonNumber');
      await _cache.set(cacheKey, response.data, ttl: CacheService.longCache);
      return SeasonData.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get season info: $e');
    }
  }

  String getPosterUrl(String? posterPath, {String size = posterSize}) {
    if (posterPath == null || posterPath.isEmpty) {
      return '';
    }
    return '$tmdbImageBaseUrl/$size$posterPath';
  }

  String getBackdropUrl(String? backdropPath, {String size = backdropSize}) {
    if (backdropPath == null || backdropPath.isEmpty) {
      return '';
    }
    return '$tmdbImageBaseUrl/$size$backdropPath';
  }

  Future<List<dynamic>> getFeaturedAnime() async {
    final trending = await getTrendingAnime();
    if (trending.length <= 10) return trending;
    return trending.take(10).toList();
  }

  Future<List<dynamic>> getAnime() async {
    final cacheKey = 'anime_popular';

    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      return (cached['results'] as List<dynamic>?) ?? [];
    }

    try {
      final response = await _dio.get(
        '/3/discover/tv',
        queryParameters: {
          'with_genres': '16',
          'with_original_language': 'ja',
          'sort_by': 'popularity.desc',
          'vote_count.gte': 20,
          'page': 1,
        },
      );

      await _cache.set(cacheKey, response.data, ttl: CacheService.mediumCache);
      return (response.data['results'] as List<dynamic>?) ?? [];
    } catch (e) {
      throw Exception('Failed to get anime: $e');
    }
  }

  Future<List<dynamic>> getTrendingAnime() async {
    final cacheKey = 'anime_trending';

    final staleCache = await _cache.getStaleRaw(cacheKey);
    if (_cache.isExpired(cacheKey)) {
      _cache.updateInBackground(cacheKey, () async {
        final response = await _dio.get(
          '/3/discover/tv',
          queryParameters: {
            'with_genres': '16',
            'with_original_language': 'ja',
            'sort_by': 'popularity.desc',
            'vote_average.gte': 6.0,
            'vote_count.gte': 50,
            'first_air_date.gte': DateTime.now()
                .subtract(const Duration(days: 1825))
                .toIso8601String()
                .split('T')[0],
            'page': 1,
          },
        );
        return response.data;
      }, CacheService.shortCache);
    }

    if (staleCache != null) {
      return (staleCache['results'] as List<dynamic>?) ?? [];
    }

    try {
      final response = await _dio.get(
        '/3/discover/tv',
        queryParameters: {
          'with_genres': '16',
          'with_original_language': 'ja',
          'sort_by': 'popularity.desc',
          'vote_average.gte': 6.0,
          'vote_count.gte': 50,
          'first_air_date.gte': DateTime.now()
              .subtract(const Duration(days: 1825))
              .toIso8601String()
              .split('T')[0],
          'page': 1,
        },
      );
      await _cache.set(cacheKey, response.data, ttl: CacheService.shortCache);
      return (response.data['results'] as List<dynamic>?) ?? [];
    } catch (e) {
      throw Exception('Failed to get trending anime: $e');
    }
  }

  Future<List<dynamic>> getTopRatedAnime() async {
    final cacheKey = 'anime_top_rated';

    final staleCache = await _cache.getStaleRaw(cacheKey);
    if (_cache.isExpired(cacheKey)) {
      _cache.updateInBackground(cacheKey, () async {
        final response = await _dio.get(
          '/3/discover/tv',
          queryParameters: {
            'with_genres': '16',
            'with_original_language': 'ja',
            'sort_by': 'vote_average.desc',
            'vote_count.gte': 200,
            'page': 1,
          },
        );
        return response.data;
      }, CacheService.mediumCache);
    }

    if (staleCache != null) {
      return (staleCache['results'] as List<dynamic>?) ?? [];
    }

    try {
      final response = await _dio.get(
        '/3/discover/tv',
        queryParameters: {
          'with_genres': '16',
          'with_original_language': 'ja',
          'sort_by': 'vote_average.desc',
          'vote_count.gte': 200,
          'page': 1,
        },
      );
      await _cache.set(cacheKey, response.data, ttl: CacheService.mediumCache);
      return (response.data['results'] as List<dynamic>?) ?? [];
    } catch (e) {
      throw Exception('Failed to get top rated anime: $e');
    }
  }

  Future<SearchResult> getTVShowDetails(int tvId) async {
    final cacheKey = 'anime_details_$tvId';

    final cached = await _cache.get<SearchResult>(
      cacheKey,
      (json) => SearchResult.fromJson(json),
    );
    if (cached != null) return cached;

    try {
      final response = await _dio.get(
        '/3/tv/$tvId',
        queryParameters: {
          'language': 'en',
          'append_to_response': 'credits,videos',
        },
      );

      final data = Map<String, dynamic>.from(response.data);
      data['media_type'] = 'tv';

      await _cache.set(cacheKey, data, ttl: CacheService.longCache);
      return SearchResult.fromJson(data);
    } catch (e) {
      throw Exception('Failed to get anime details: $e');
    }
  }

  Future<Map<String, dynamic>> getTVShowDetailsWithVideos(int tvId) async {
    final cacheKey = 'anime_details_videos_$tvId';

    final staleCache = await _cache.getStaleRaw(cacheKey);
    if (staleCache != null && _cache.isExpired(cacheKey)) {
      _cache.updateInBackground(cacheKey, () async {
        final response = await _dio.get(
          '/3/tv/$tvId',
          queryParameters: {'language': 'en', 'append_to_response': 'videos'},
        );
        return response.data;
      }, CacheService.longCache);
      return staleCache;
    }

    if (staleCache != null) return staleCache;

    try {
      final response = await _dio.get(
        '/3/tv/$tvId',
        queryParameters: {'language': 'en', 'append_to_response': 'videos'},
      );

      final data = Map<String, dynamic>.from(response.data);
      data['media_type'] = 'tv';
      await _cache.set(cacheKey, data, ttl: CacheService.longCache);

      return data;
    } catch (e) {
      throw Exception('Failed to get anime details with videos: $e');
    }
  }

  /// Returns the best English logo image URL for a TV show, or null if none.
  Future<String?> getTVShowLogoUrl(int id) async {
    final cacheKey = 'tv_logo_$id';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final path = cached['logo_path'] as String?;
      return (path != null && path.isNotEmpty) ? '$tmdbImageBaseUrl/w500$path' : null;
    }

    try {
      final response = await _dio.get(
        '/3/tv/$id/images',
        queryParameters: {'include_image_language': 'en,null'},
      );
      final logos = (response.data['logos'] as List<dynamic>? ?? []);
      logos.sort(
        (a, b) => ((b['vote_average'] as num?) ?? 0)
            .compareTo((a['vote_average'] as num?) ?? 0),
      );
      final logoPath =
          logos.isNotEmpty ? logos.first['file_path'] as String? : null;

      await _cache.set(
        cacheKey,
        {'logo_path': logoPath ?? ''},
        ttl: CacheService.longCache,
      );

      return (logoPath != null && logoPath.isNotEmpty)
          ? '$tmdbImageBaseUrl/w500$logoPath'
          : null;
    } catch (_) {
      return null;
    }
  }
}
