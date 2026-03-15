import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:aimi_lib/aimi_lib.dart' as aimi;
import 'package:namizo/core/config.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/models/media/season_info.dart';
import 'package:namizo/core/cache.dart';
import 'package:namizo/models/tvdb/tvdb_models.dart';
import 'package:namizo/services/tvdb.dart';
import 'package:namizo/utils/image_url.dart' as img_util;

class KuroiruService {
  final Dio _jikanDio;
  final Dio _kuroiruDio;
  final aimi.Kuroiru _kuroiru;
  final TvdbMetadataService _tvdbMetadata;
  final CacheService _cache;
  final Map<String, Future<List<dynamic>>> _inFlightHomeRequests = {};

  KuroiruService(this._cache)
    : _jikanDio = Dio(
        BaseOptions(
          baseUrl: AppConfigurations.jikanBaseUrl,
          connectTimeout: standardTimeout,
          receiveTimeout: standardTimeout,
          headers: {'User-Agent': AppConfigurations.defaultAppUserAgent},
        ),
      ),
      _kuroiruDio = Dio(
        BaseOptions(
          baseUrl: 'https://kuroiru.co',
          connectTimeout: standardTimeout,
          receiveTimeout: standardTimeout,
          headers: {'User-Agent': AppConfigurations.defaultAppUserAgent},
        ),
      ),
      _kuroiru = aimi.Kuroiru(),
      _tvdbMetadata = TvdbMetadataService(_cache);

  Future<List<Map<String, dynamic>>> getAiringCalendar() async {
    const cacheKey = 'kuroiru_airing_calendar';

    final staleCache = await _cache.getStaleRaw(cacheKey);
    if (_cache.isExpired(cacheKey)) {
      _cache.updateInBackground(cacheKey, () async {
        final airing = await _fetchAiringCalendarFromHome();
        return {'airing': airing};
      }, shortCache);
    }

    if (staleCache != null) {
      return _mapAiringList(staleCache['airing']);
    }

    final airing = await _fetchAiringCalendarFromHome();
    await _cache.set(cacheKey, {'airing': airing}, ttl: shortCache);
    return airing;
  }

  Future<List<Map<String, dynamic>>> _fetchAiringCalendarFromHome() async {
    try {
      final response = await _kuroiruDio.get('/app');
      final html = response.data?.toString() ?? '';

      final match = RegExp(
        r'var\s+airingList\s*=\s*(\{[\s\S]*?\});',
      ).firstMatch(html);

      if (match == null || match.groupCount < 1) {
        throw Exception('airingList payload not found');
      }

      final payload = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      return _mapAiringList(payload['airing']);
    } catch (e) {
      throw Exception('Failed to get Kuroiru airing calendar: $e');
    }
  }

  List<Map<String, dynamic>> _mapAiringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<SearchResults> search(
    String query, {
    int page = 1,
    String? language,
    String? sortBy,
    List<int>? genreIds,
    String? status,
    String? type,
    int? startYear,
    int? endYear,
    double? minScore,
  }) async {
    final normalizedQuery = _normalizeSearchText(query);
    final normalizedSort = sortBy == 'rating' ? 'score' : sortBy;
    final normalizedType = type?.trim().toLowerCase();
    final normalizedStatus = status?.trim().toLowerCase();
    final normalizedGenres =
        (genreIds ?? const <int>[]).where((id) => id > 0).toSet().toList()
          ..sort();
    final normalizedStartYear = startYear;
    final normalizedEndYear = endYear;
    final normalizedMinScore = minScore;

    final genreCachePart = normalizedGenres.isEmpty
        ? 'none'
        : normalizedGenres.join('-');
    final yearCachePart =
        '${normalizedStartYear ?? 'none'}-${normalizedEndYear ?? 'none'}';
    final scoreCachePart = normalizedMinScore == null
        ? 'none'
        : normalizedMinScore.toStringAsFixed(1);
    final cacheKey =
        'search_anime_${normalizedQuery}_${page}_${normalizedSort ?? 'relevance'}_${language ?? 'all'}_g:${genreCachePart}_s:${normalizedStatus ?? 'all'}_t:${normalizedType ?? 'all'}_y:${yearCachePart}_sc:${scoreCachePart}';

    if (normalizedQuery.isEmpty) {
      return const SearchResults(
        page: 0,
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
      Map<String, dynamic>? jikanData;
      List<SearchResult> jikanParsed = const [];

      try {
        final response = await _jikanGetWithRetry(
          '/anime',
          queryParameters: {
            'q': normalizedQuery,
            'page': page,
            'sfw': true,
            'limit': 25,
            if (normalizedGenres.isNotEmpty)
              'genres': normalizedGenres.join(','),
            if (normalizedStatus != null && normalizedStatus.isNotEmpty)
              'status': normalizedStatus,
            if (normalizedType != null && normalizedType.isNotEmpty)
              'type': normalizedType,
            if (normalizedStartYear != null)
              'start_date':
                  '${normalizedStartYear.toString().padLeft(4, '0')}-01-01',
            if (normalizedEndYear != null)
              'end_date':
                  '${normalizedEndYear.toString().padLeft(4, '0')}-12-31',
            if (normalizedMinScore != null) 'min_score': normalizedMinScore,
            ..._searchSortToJikanParams(normalizedSort),
          },
        );
        jikanData = Map<String, dynamic>.from(response.data as Map);
        jikanParsed = _parseJikanSearchResults(jikanData['data']);
      } catch (_) {
        jikanData = null;
      }

      List<SearchResult> mappedKuroiru = const [];
      if (page == 1) {
        try {
          final kuroiruResults = await _kuroiru.search(normalizedQuery);
          mappedKuroiru = _mapKuroiruSearchResults(kuroiruResults);
        } catch (_) {
          mappedKuroiru = const [];
        }
      }

      if (jikanData == null && mappedKuroiru.isEmpty) {
        throw Exception('No search sources available');
      }

      final combined = page == 1
          ? _mergeUniqueSearchResults(mappedKuroiru, jikanParsed)
          : jikanParsed;

      final processed = _postProcessSearchResults(
        combined,
        query: normalizedQuery,
        sortBy: normalizedSort,
      );

      final pagination = (jikanData?['pagination'] as Map?)
          ?.cast<String, dynamic>();
      final jikanTotalPages =
          (pagination?['last_visible_page'] as num?)?.toInt() ??
          (processed.isEmpty ? 0 : 1);
      final jikanTotalResults =
          (pagination?['items']?['total'] as num?)?.toInt() ?? processed.length;

      const pageSize = 25;
      final pageResults = page == 1 && processed.length > pageSize
          ? processed.take(pageSize).toList(growable: false)
          : processed;

      final merged = SearchResults(
        page: page,
        results: pageResults,
        totalPages: jikanTotalPages,
        totalResults: jikanTotalResults > pageResults.length
            ? jikanTotalResults
            : pageResults.length,
      );

      await _cache.set(cacheKey, merged.toJson(), ttl: mediumCache);
      return merged;
    } catch (e) {
      throw Exception('Failed to search anime (Kuroiru/Jikan): $e');
    }
  }

  List<SearchResult> _mapKuroiruSearchResults(
    List<aimi.AnimeSearchResult> raw,
  ) {
    final mapped = <SearchResult>[];

    for (final item in raw) {
      final id = int.tryParse(item.id);
      if (id == null) continue;

      mapped.add(
        SearchResult(
          id: id,
          title: item.title,
          name: item.title,
          originalLanguage: 'ja',
          mediaType: 'tv',
          firstAirDate: _extractIsoDateFromLooseYear(item.time),
          posterPath: item.image,
          backdropPath: item.image,
          overview: null,
          voteAverage: null,
        ),
      );
    }

    return mapped;
  }

  List<SearchResult> _mergeUniqueSearchResults(
    List<SearchResult> primary,
    List<SearchResult> secondary,
  ) {
    final merged = <SearchResult>[];
    final seen = <String>{};

    for (final item in primary) {
      final key = '${item.id}';
      if (seen.add(key)) merged.add(item);
    }

    for (final item in secondary) {
      final key = '${item.id}';
      if (seen.add(key)) merged.add(item);
    }

    return merged;
  }

  String? _extractIsoDateFromLooseYear(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    final match = RegExp(r'(19|20)\d{2}').firstMatch(source);
    if (match == null) return null;
    final year = match.group(0);
    return year == null ? null : '$year-01-01';
  }

  List<SearchResult> _parseJikanSearchResults(dynamic rawResults) {
    if (rawResults is! List) return const [];

    final parsed = <SearchResult>[];
    for (final item in rawResults) {
      if (item is! Map) continue;
      final mal = Map<String, dynamic>.from(item);
      final malId = (mal['mal_id'] as num?)?.toInt();
      if (malId == null) continue;

      final images = (mal['images'] as Map?)?.cast<String, dynamic>();
      final jpg = (images?['jpg'] as Map?)?.cast<String, dynamic>();
      final posterUrl =
          (jpg?['large_image_url'] ?? jpg?['image_url']) as String?;

      final genres = (mal['genres'] as List<dynamic>? ?? [])
          .map((g) => (g as Map?)?['mal_id'])
          .whereType<num>()
          .map((id) => id.toInt())
          .toList();

      final rating = mal['rating']?.toString().toLowerCase() ?? '';
      final hasAdultRating = rating.contains('rx') || rating.contains('hentai');
      final hasAdultGenre = genres.contains(12);
      final isAdult = hasAdultRating || hasAdultGenre;

      parsed.add(
        SearchResult(
          adult: isAdult,
          id: malId,
          name: mal['title'] as String?,
          title: mal['title_english'] as String? ?? mal['title'] as String?,
          originalLanguage: 'ja',
          mediaType: (mal['type'] as String?)?.toLowerCase() ?? 'tv',
          firstAirDate: _extractIsoDate(mal['aired']?['from']),
          posterPath: posterUrl,
          backdropPath: posterUrl,
          overview: mal['synopsis'] as String?,
          voteAverage: (mal['score'] as num?)?.toDouble(),
        ),
      );

      _genreCacheByMalId[malId] = genres;
      _episodeCountByMalId[malId] = (mal['episodes'] as num?)?.toInt();
      _airingByMalId[malId] = mal['airing'] == true;
      _statusByMalId[malId] = mal['status']?.toString();
    }
    return parsed;
  }

  final Map<int, List<int>> _genreCacheByMalId = <int, List<int>>{};
  final Map<int, int?> _episodeCountByMalId = <int, int?>{};
  final Map<int, bool> _airingByMalId = <int, bool>{};
  final Map<int, String?> _statusByMalId = <int, String?>{};

  List<int> getCachedGenreIds(int malId) =>
      List<int>.from(_genreCacheByMalId[malId] ?? const <int>[]);

  int? getCachedEpisodeCount(int malId) => _episodeCountByMalId[malId];

  bool? getCachedAiring(int malId) => _airingByMalId[malId];

  String? getCachedStatus(int malId) => _statusByMalId[malId];

  Map<String, dynamic> _searchSortToJikanParams(String? sortBy) {
    switch (sortBy) {
      case 'az':
      case 'title':
        return {'order_by': 'title', 'sort': 'asc'};
      case 'newest':
      case 'year':
        return {'order_by': 'start_date', 'sort': 'desc'};
      case 'airing_now':
        return {'order_by': 'popularity', 'sort': 'desc'};
      case 'score':
      case 'rating':
        return {'order_by': 'score', 'sort': 'desc'};
      case 'popularity':
        return {'order_by': 'members', 'sort': 'desc'};
      default:
        return const {};
    }
  }

  List<SearchResult> _postProcessSearchResults(
    List<SearchResult> results, {
    required String query,
    String? sortBy,
  }) {
    var processed = List<SearchResult>.from(results);

    final seen = <String>{};
    processed = processed.where((item) => seen.add('${item.id}')).toList();

    switch (sortBy) {
      case 'score':
      case 'rating':
        processed.sort((a, b) {
          final ratingCompare = (b.voteAverage ?? 0).compareTo(
            a.voteAverage ?? 0,
          );
          if (ratingCompare != 0) return ratingCompare;
          return _compareByYearDesc(a, b);
        });
        break;
      case 'newest':
      case 'start_date':
      case 'year':
        processed.sort(_compareByYearDesc);
        break;
      case 'az':
      case 'title':
        processed.sort((a, b) {
          final titleA = _normalizeSearchText(a.title ?? a.name ?? '');
          final titleB = _normalizeSearchText(b.title ?? b.name ?? '');
          return titleA.compareTo(titleB);
        });
        break;
      case 'popularity':
        processed.sort((a, b) {
          final ratingCompare = (b.voteAverage ?? 0).compareTo(
            a.voteAverage ?? 0,
          );
          if (ratingCompare != 0) return ratingCompare;
          return _compareByYearDesc(a, b);
        });
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
      final details = await _kuroiru.getDetails('$showId');
      final episodes = details.episodes ?? details.lastEpisode ?? 0;
      final mapped = SeriesInfo(
        numberOfSeasons: 1,
        seasons: [
          SeasonInfo(
            episodeCount: episodes,
            id: showId,
            name: 'Season 1',
            seasonNumber: 1,
            airDate: _airedIntToIso(details.airedInt),
            posterPath: details.image,
          ),
        ],
      );
      await _cache.set(cacheKey, mapped.toJson(), ttl: longCache);
      return mapped;
    } catch (e) {
      throw Exception('Failed to get anime series info from Kuroiru: $e');
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
      if (seasonNumber != 1) {
        const empty = SeasonData(episodes: []);
        await _cache.set(cacheKey, empty.toJson(), ttl: longCache);
        return empty;
      }

      final details = await _kuroiru.getDetails('$showId');
      final episodeCount = details.episodes ?? details.lastEpisode ?? 0;
      final runtime = _parseDurationMinutes(details.duration);
      final episodes = List<EpisodeData>.generate(episodeCount, (index) {
        final episodeNumber = index + 1;
        return EpisodeData(
          episodeNumber: episodeNumber,
          episodeName: 'Episode $episodeNumber',
          overview: details.description,
          stillPath: details.image,
          voteAverage: details.score,
          runtime: runtime,
          airDate: _airedIntToIso(details.airedInt),
        );
      });

      final mapped = SeasonData(episodes: episodes);
      final enriched = await _tvdbMetadata.enrichSeasonData(
        malId: showId,
        seasonNumber: seasonNumber,
        fallback: mapped,
      );
      await _cache.set(cacheKey, enriched.toJson(), ttl: longCache);
      return enriched;
    } catch (e) {
      throw Exception('Failed to get season info from Kuroiru: $e');
    }
  }

  String getPosterUrl(String? posterPath, {String size = posterSize}) =>
      img_util.posterUrl(posterPath, size: size);

  String getBackdropUrl(String? backdropPath, {String size = backdropSize}) =>
      img_util.backdropUrl(backdropPath, size: size);

  Future<List<dynamic>> getFeaturedAnime() async {
    final trending = await getTrendingAnime();
    if (trending.length <= 10) return trending;
    return trending.take(10).toList();
  }

  Future<List<dynamic>> getAnime() async {
    return _runSingleFlightList('anime_popular', () async {
      final cacheKey = 'anime_popular';

      final cached = await _cache.getRaw(cacheKey);
      if (cached != null) {
        return (cached['results'] as List<dynamic>?) ?? [];
      }

      try {
        final results = await _fetchJikanAnimeList(
          queryParameters: {
            'type': 'tv',
            'order_by': 'members',
            'sort': 'desc',
            'sfw': true,
            'limit': 25,
            'page': 1,
          },
        );
        await _cache.set(cacheKey, {'results': results}, ttl: mediumCache);
        return results;
      } catch (e) {
        throw Exception('Failed to get anime: $e');
      }
    });
  }

  Future<List<dynamic>> getTrendingAnime() async {
    return _runSingleFlightList('anime_trending', () async {
      final cacheKey = 'anime_trending';

      final staleCache = await _cache.getStaleRaw(cacheKey);
      if (_cache.isExpired(cacheKey)) {
        _cache.updateInBackground(cacheKey, () async {
          final results = await _fetchJikanCurrentSeasonAnime(limit: 25);
          return {'results': results};
        }, shortCache);
      }

      if (staleCache != null) {
        return (staleCache['results'] as List<dynamic>?) ?? [];
      }

      try {
        final results = await _fetchJikanCurrentSeasonAnime(limit: 25);
        await _cache.set(cacheKey, {'results': results}, ttl: shortCache);
        return results;
      } catch (e) {
        throw Exception('Failed to get trending anime: $e');
      }
    });
  }

  Future<List<dynamic>> getTopRatedAnime() async {
    return _runSingleFlightList('anime_top_rated', () async {
      final cacheKey = 'anime_top_rated';

      final staleCache = await _cache.getStaleRaw(cacheKey);
      if (_cache.isExpired(cacheKey)) {
        _cache.updateInBackground(cacheKey, () async {
          final results = await _fetchJikanTopAnime(limit: 25);
          return {'results': results};
        }, mediumCache);
      }

      if (staleCache != null) {
        return (staleCache['results'] as List<dynamic>?) ?? [];
      }

      try {
        final results = await _fetchJikanTopAnime(limit: 25);
        await _cache.set(cacheKey, {'results': results}, ttl: mediumCache);
        return results;
      } catch (e) {
        throw Exception('Failed to get top rated anime: $e');
      }
    });
  }

  Future<List<dynamic>> getAnimeByGenre(
    int genreId, {
    String sortBy = 'popularity.desc',
    int voteCountGte = 20,
  }) async {
    return _runSingleFlightList(
      'anime_genre_${genreId}_${sortBy.replaceAll('.', '_')}_$voteCountGte',
      () async {
        final cacheKey =
            'anime_genre_${genreId}_${sortBy.replaceAll('.', '_')}_$voteCountGte';

        final staleCache = await _cache.getStaleRaw(cacheKey);
        if (_cache.isExpired(cacheKey)) {
          _cache.updateInBackground(cacheKey, () async {
            final mappedGenreId = _mapTmdbGenreToMal(genreId);
            final results = await _fetchJikanAnimeList(
              queryParameters: {
                'type': 'tv',
                'genres': mappedGenreId,
                'sfw': true,
                'limit': 25,
                'page': 1,
                ..._sortToJikan(sortBy),
              },
            );
            return {'results': results};
          }, mediumCache);
        }

        if (staleCache != null) {
          return (staleCache['results'] as List<dynamic>?) ?? [];
        }

        try {
          final mappedGenreId = _mapTmdbGenreToMal(genreId);
          final results = await _fetchJikanAnimeList(
            queryParameters: {
              'type': 'tv',
              'genres': mappedGenreId,
              'sfw': true,
              'limit': 25,
              'page': 1,
              ..._sortToJikan(sortBy),
            },
          );
          await _cache.set(cacheKey, {'results': results}, ttl: mediumCache);
          return results;
        } catch (e) {
          throw Exception('Failed to get genre anime: $e');
        }
      },
    );
  }

  Future<List<dynamic>> _runSingleFlightList(
    String key,
    Future<List<dynamic>> Function() request,
  ) {
    final existing = _inFlightHomeRequests[key];
    if (existing != null) return existing;

    final future = request();
    _inFlightHomeRequests[key] = future;
    future.whenComplete(() => _inFlightHomeRequests.remove(key));
    return future;
  }

  Future<SearchResult> getTVShowDetails(int tvId) async {
    final cacheKey = 'anime_details_$tvId';

    final cached = await _cache.get<SearchResult>(
      cacheKey,
      (json) => SearchResult.fromJson(json),
    );
    if (cached != null) return cached;

    try {
      final details = await _kuroiru.getDetails('$tvId');
      final mapped = await _enrichSearchResultWithTvdbArtwork(
        tvId,
        _toSearchResult(details),
      );

      await _cache.set(cacheKey, mapped.toJson(), ttl: longCache);
      return mapped;
    } catch (e) {
      throw Exception('Failed to get anime details from Kuroiru: $e');
    }
  }

  Future<Map<String, dynamic>> getTVShowDetailsWithVideos(int tvId) async {
    final cacheKey = 'anime_details_videos_v2_$tvId';

    final staleCache = await _cache.getStaleRaw(cacheKey);
    if (staleCache != null && _cache.isExpired(cacheKey)) {
      _cache.updateInBackground(cacheKey, () async {
        final details = await _kuroiru.getDetails('$tvId');
        return _toDetailWithVideosMap(tvId, details);
      }, longCache);
      return staleCache;
    }

    if (staleCache != null) return staleCache;

    try {
      final details = await _kuroiru.getDetails('$tvId');
      final data = await _toDetailWithVideosMap(tvId, details);
      await _cache.set(cacheKey, data, ttl: longCache);

      return data;
    } catch (e) {
      throw Exception(
        'Failed to get anime details with videos from Kuroiru: $e',
      );
    }
  }

  /// Returns the best English logo image URL for a TV show, or null if none.
  Future<String?> getTVShowLogoUrl(int id) async {
    return _tvdbMetadata.getClearLogoUrlForMalId(id);
  }

  /// Returns TVDB banner/fanart URL for a TV show, or null if none.
  Future<String?> getTVShowBannerUrl(int id) async {
    final artwork = await _tvdbMetadata.getArtworkForMalId(id);
    return artwork?.bannerUrl;
  }

  /// Returns TVDB carousel-optimized image URL for a TV show, or null if none.
  Future<String?> getTVShowCarouselImageUrl(int id) async {
    return _tvdbMetadata.getCarouselBackdropUrlForMalId(id);
  }

  /// Returns TVDB poster/cover URL for a TV show, or null if none.
  Future<String?> getTVShowPosterUrl(int id) async {
    final artwork = await _tvdbMetadata.getArtworkForMalId(id);
    return artwork?.posterUrl;
  }

  /// Returns a strict no-text poster/keyart URL for carousel use, or null.
  Future<String?> getTVShowNoTextPosterUrl(int id) async {
    return _tvdbMetadata.getNoTextPosterUrlForMalId(id);
  }

  /// Returns similar anime recommendations (MAL/Jikan) for "More Like This".
  /// Falls back to TVDB if recommendations are unavailable.
  Future<List<TvdbSimilarSeries>> getTVShowSimilarFromTvdb(int id) async {
    final cacheKey = 'similar_recommendations_anime_only_v3_$id';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final rows = cached['items'];
      if (rows is List) {
        return rows
            .whereType<Map>()
            .map(
              (row) => TvdbSimilarSeries.fromJson(row.cast<String, dynamic>()),
            )
            .where(
              (item) => (item.sourceType ?? 'anime').toLowerCase() == 'anime',
            )
            .toList(growable: false);
      }
    }

    final jikanRecommendations = await _fetchJikanAnimeRecommendations(id);
    if (jikanRecommendations.isNotEmpty) {
      await _cache.set(cacheKey, {
        'items': jikanRecommendations
            .map((item) => item.toJson())
            .toList(growable: false),
      }, ttl: mediumCache);
      return jikanRecommendations;
    }

    final tvdbPrimary = await _tvdbMetadata.getSimilarSeriesForMalId(id);
    final animeOnlyPrimary = tvdbPrimary
        .where((item) => (item.sourceType ?? 'anime').toLowerCase() == 'anime')
        .toList(growable: false);
    if (animeOnlyPrimary.isNotEmpty) {
      await _cache.set(cacheKey, {
        'items': animeOnlyPrimary
            .map((item) => item.toJson())
            .toList(growable: false),
      }, ttl: mediumCache);
      return animeOnlyPrimary;
    }

    // Last fallback path only when recommendation sources are empty.
    final kuroiruFallback = await _fetchKuroiruRelatedAnime(id);
    final animeOnlyFallback = kuroiruFallback
        .where((item) => (item.sourceType ?? 'anime').toLowerCase() == 'anime')
        .toList(growable: false);
    await _cache.set(cacheKey, {
      'items': animeOnlyFallback
          .map((item) => item.toJson())
          .toList(growable: false),
    }, ttl: mediumCache);
    return animeOnlyFallback;
  }

  Future<List<TvdbSimilarSeries>> _fetchJikanAnimeRecommendations(
    int malId,
  ) async {
    try {
      final response = await _jikanGetWithRetry(
        '/anime/$malId/recommendations',
      );
      final root = response.data;
      if (root is! Map) return const [];

      final data = root['data'];
      if (data is! List) return const [];

      final out = <TvdbSimilarSeries>[];
      final seen = <int>{};

      for (final row in data.whereType<Map>()) {
        final item = row.cast<String, dynamic>();
        final entry = item['entry'];
        if (entry is! Map) continue;

        final entryMap = entry.cast<String, dynamic>();
        final relatedMalId = _toInt(entryMap['mal_id']);
        if (relatedMalId == null || relatedMalId <= 0) continue;
        if (relatedMalId == malId || !seen.add(relatedMalId)) continue;

        final title = (entryMap['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;

        String? poster;
        final images = entryMap['images'];
        if (images is Map) {
          final jpg = images['jpg'];
          if (jpg is Map) {
            poster = (jpg['large_image_url'] ?? jpg['image_url'])
                ?.toString()
                .trim();
          }
        }

        final votes = _toInt(item['votes']);
        out.add(
          TvdbSimilarSeries(
            tvdbId: null,
            malId: relatedMalId,
            sourceType: 'anime',
            title: title,
            overview: null,
            imageUrl: poster,
            score: votes?.toDouble(),
            year: null,
          ),
        );

        if (out.length >= 18) break;
      }

      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<TvdbSimilarSeries>> _fetchKuroiruRelatedAnime(int malId) async {
    try {
      final response = await _kuroiruDio.post(
        '/backend/api',
        data: 'prompt=$malId',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Referer': 'https://kuroiru.co/',
            'User-Agent': AppConfigurations.defaultAppUserAgent,
          },
        ),
      );

      final root = response.data;
      if (root is! Map) return const [];

      final related = root['related'];
      if (related is! Map) return const [];

      final collected = <TvdbSimilarSeries>[];
      final seen = <int>{};

      for (final entry in related.entries) {
        final value = entry.value;
        if (value is! List) continue;

        for (final row in value.whereType<Map>()) {
          final item = row.cast<String, dynamic>();
          final type = item['type']?.toString().toLowerCase();
          final sourceType = (type == 'manga') ? 'manga' : 'anime';

          final relatedMalId = _toInt(item['mal_id']);
          if (relatedMalId == null || relatedMalId <= 0) continue;
          if (relatedMalId == malId || !seen.add(relatedMalId)) continue;

          final title = item['name']?.toString().trim();
          if (title == null || title.isEmpty) continue;

          final imageUrl = _normalizeKuroiruImage(item['img']?.toString());
          collected.add(
            TvdbSimilarSeries(
              tvdbId: null,
              malId: relatedMalId,
              sourceType: sourceType,
              title: title,
              overview: null,
              imageUrl: imageUrl,
              score: null,
              year: null,
            ),
          );

          if (collected.length >= 18) break;
        }

        if (collected.length >= 18) break;
      }

      if (collected.isEmpty) return const [];

      final enriched = await Future.wait(
        collected.map((item) async {
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) return item;
          final jikanPoster = await _fetchJikanPosterForMalId(item.malId!);
          if (jikanPoster == null || jikanPoster.isEmpty) return item;
          return TvdbSimilarSeries(
            tvdbId: item.tvdbId,
            malId: item.malId,
            sourceType: item.sourceType,
            title: item.title,
            overview: item.overview,
            imageUrl: jikanPoster,
            score: item.score,
            year: item.year,
          );
        }),
      );

      return enriched;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _fetchJikanPosterForMalId(int malId) async {
    final cacheKey = 'jikan_poster_$malId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final url = cached['poster']?.toString();
      return (url != null && url.isNotEmpty) ? url : null;
    }

    try {
      final response = await _jikanGetWithRetry('/anime/$malId');
      final root = response.data;
      if (root is! Map) return null;
      final data = root['data'];
      if (data is! Map) return null;
      final images = data['images'];
      if (images is! Map) return null;
      final jpg = images['jpg'];
      if (jpg is! Map) return null;

      final poster = (jpg['large_image_url'] ?? jpg['image_url'])
          ?.toString()
          .trim();
      await _cache.set(cacheKey, {'poster': poster ?? ''}, ttl: longCache);

      return (poster != null && poster.isNotEmpty) ? poster : null;
    } catch (_) {
      return null;
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _normalizeKuroiruImage(String? path) {
    if (path == null || path.isEmpty) return null;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    if (path.startsWith('/img/')) {
      final regex = RegExp(r'^/img/(\d+)/(\d+)\.jpg$');
      final match = regex.firstMatch(path);
      if (match != null) {
        return 'https://cdn.myanimelist.net/images/anime/${match.group(1)}/${match.group(2)}l.jpg';
      }
      return 'https://kuroiru.co$path';
    }

    if (path.startsWith('/')) {
      return 'https://kuroiru.co$path';
    }

    return path;
  }

  SearchResult _toSearchResult(aimi.AnimeDetails details) {
    final id = int.tryParse(details.id) ?? 0;
    return SearchResult(
      id: id,
      name: details.title,
      title: details.titleEn?.trim().isNotEmpty == true
          ? details.titleEn
          : details.title,
      originalLanguage: 'ja',
      mediaType: 'tv',
      releaseDate: _airedIntToIso(details.airedInt),
      firstAirDate: _airedIntToIso(details.airedInt),
      posterPath: details.image,
      backdropPath: details.image,
      overview: details.description,
      voteAverage: details.score,
    );
  }

  Future<Map<String, dynamic>> _toDetailWithVideosMap(
    int malId,
    aimi.AnimeDetails details,
  ) async {
    final enriched = await _enrichSearchResultWithTvdbArtwork(
      malId,
      _toSearchResult(details),
    );
    final mapped = enriched.toJson();
    final trailerUrl = await _getKuroiruTrailerUrl(malId);
    final trailerKey = _extractYouTubeVideoId(trailerUrl);

    mapped['genres'] = (details.genres ?? const <String>[])
        .map((genre) => {'id': 0, 'name': genre})
        .toList();

    mapped['trailer_url'] = trailerUrl ?? '';
    mapped['videos'] = {
      'results': trailerKey == null
          ? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[
              {
                'site': 'YouTube',
                'type': 'Trailer',
                'official': true,
                'key': trailerKey,
              },
            ],
    };

    return mapped;
  }

  Future<String?> _getKuroiruTrailerUrl(int malId) async {
    final cacheKey = 'kuroiru_trailer_url_v1_$malId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final cachedUrl = cached['url']?.toString().trim();
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        return cachedUrl;
      }
      return null;
    }

    try {
      final response = await _kuroiruDio.post(
        '/backend/api',
        data: 'prompt=$malId',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Referer': 'https://kuroiru.co/',
            'User-Agent': AppConfigurations.defaultAppUserAgent,
          },
        ),
      );

      final data = response.data;
      String? trailerUrl;
      if (data is Map) {
        final mapped = data.cast<String, dynamic>();
        trailerUrl =
            _normalizeKuroiruTrailer(mapped['yt']) ??
            _normalizeKuroiruTrailer(mapped['trailer']) ??
            _normalizeKuroiruTrailer(mapped['youtube']) ??
            _extractYoutubeWatchUrlFromLinks(mapped['links']);
      }

      await _cache.set(cacheKey, {'url': trailerUrl ?? ''}, ttl: longCache);
      return trailerUrl;
    } catch (_) {
      return null;
    }
  }

  String? _normalizeKuroiruTrailer(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;

    final youtubeIdPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (youtubeIdPattern.hasMatch(value)) {
      return 'https://www.youtube.com/watch?v=$value';
    }

    final fullMatch = RegExp(
      r'(https?:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/)[a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ).firstMatch(value);
    if (fullMatch != null) {
      return fullMatch.group(1);
    }

    return null;
  }

  String? _extractYoutubeWatchUrlFromLinks(dynamic links) {
    if (links is! List) return null;
    for (final item in links.whereType<Map>()) {
      final row = item.cast<String, dynamic>();
      final url = row['url']?.toString().trim();
      if (url == null || url.isEmpty) continue;
      if (!url.contains('youtube.com/watch') && !url.contains('youtu.be/')) {
        continue;
      }
      return _normalizeKuroiruTrailer(url) ?? url;
    }
    return null;
  }

  String? _extractYouTubeVideoId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final normalized = url.trim();
    final idPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (idPattern.hasMatch(normalized)) {
      return normalized;
    }
    final match = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ).firstMatch(normalized);
    return match?.group(1);
  }

  Future<SearchResult> _enrichSearchResultWithTvdbArtwork(
    int malId,
    SearchResult fallback,
  ) async {
    final artwork = await _tvdbMetadata.getArtworkForMalId(malId);
    if (artwork == null) return fallback;

    return fallback.copyWith(
      posterPath: artwork.posterUrl ?? fallback.posterPath,
      backdropPath: artwork.bannerUrl ?? fallback.backdropPath,
    );
  }

  Map<String, dynamic> _sortToJikan(String sortBy) {
    switch (sortBy) {
      case 'vote_average.desc':
        return {'order_by': 'score', 'sort': 'desc'};
      case 'first_air_date.desc':
        return {'order_by': 'start_date', 'sort': 'desc'};
      case 'popularity.desc':
      default:
        return {'order_by': 'members', 'sort': 'desc'};
    }
  }

  int _mapTmdbGenreToMal(int tmdbGenre) {
    switch (tmdbGenre) {
      case 18:
        return 22; // Romance
      case 12:
        return 2; // Adventure
      case 10759:
        return 1; // Action
      case 10765:
        return 10; // Fantasy
      default:
        return tmdbGenre;
    }
  }

  Future<List<dynamic>> _fetchJikanCurrentSeasonAnime({int limit = 25}) async {
    final response = await _jikanGetWithRetry(
      '/seasons/now',
      queryParameters: {'limit': limit, 'sfw': true},
    );
    return _toUiList(response.data);
  }

  Future<List<dynamic>> _fetchJikanTopAnime({int limit = 25}) async {
    final response = await _jikanGetWithRetry(
      '/top/anime',
      queryParameters: {'type': 'tv', 'limit': limit, 'sfw': true},
    );
    return _toUiList(response.data);
  }

  Future<List<dynamic>> _fetchJikanAnimeList({
    required Map<String, dynamic> queryParameters,
  }) async {
    final response = await _jikanGetWithRetry(
      '/anime',
      queryParameters: queryParameters,
    );
    return _toUiList(response.data);
  }

  Future<Response<dynamic>> _jikanGetWithRetry(
    String path, {
    Map<String, dynamic>? queryParameters,
    int maxAttempts = 3,
  }) async {
    DioException? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _jikanDio.get(path, queryParameters: queryParameters);
      } on DioException catch (error) {
        lastError = error;
        final statusCode = error.response?.statusCode;
        final isRateLimit = statusCode == 429;
        final isTransient =
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError;

        final shouldRetry =
            attempt < maxAttempts && (isRateLimit || isTransient);
        if (!shouldRetry) rethrow;

        final wait = Duration(milliseconds: 600 * attempt * attempt);
        await Future.delayed(wait);
      }
    }

    throw lastError ?? Exception('Unknown Jikan request error');
  }

  List<dynamic> _toUiList(dynamic responseData) {
    final data = Map<String, dynamic>.from(responseData as Map);
    final results = _parseJikanSearchResults(data['data']);
    return results
        .map((item) {
          final json = item.toJson();
          json['genre_ids'] = _genreCacheByMalId[item.id] ?? const <int>[];
          json['episode_count'] = _episodeCountByMalId[item.id];
          json['airing'] = _airingByMalId[item.id] ?? false;
          json['status'] = _statusByMalId[item.id];
          return json;
        })
        .toList(growable: false);
  }

  String? _extractIsoDate(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString();
    if (value.length < 10) return null;
    return value.substring(0, 10);
  }

  String? _airedIntToIso(int? airedInt) {
    if (airedInt == null) return null;
    final value = airedInt.toString();
    if (value.length != 8) return null;
    final yyyy = value.substring(0, 4);
    final mm = value.substring(4, 6);
    final dd = value.substring(6, 8);
    return '$yyyy-$mm-$dd';
  }

  int? _parseDurationMinutes(String? duration) {
    if (duration == null || duration.isEmpty) return null;
    final match = RegExp(r'(\d+)\s*min').firstMatch(duration.toLowerCase());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}

@Deprecated('Use KuroiruService instead')
class TmdbService extends KuroiruService {
  TmdbService(CacheService cache) : super(cache);
}
