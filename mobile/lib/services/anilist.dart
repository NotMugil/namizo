import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:namizo/core/config.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/models/media/search_result.dart';

class AniListService {
  AniListService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfigurations.anilistGraphQlBaseUrl,
              connectTimeout: standardTimeout,
              receiveTimeout: standardTimeout,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          );

  final Dio _dio;
  static const Duration _defaultRateLimitDelay = Duration(milliseconds: 1200);
  static const Duration _syncPacingDelay = Duration(milliseconds: 700);
  static const String _namizoCustomListName = 'Watched using Namizo';

  static const String _viewerQuery = r'''
query Viewer {
  Viewer {
    id
    name
    bannerImage
    avatar {
      large
      medium
    }
    statistics {
      anime {
        count
        episodesWatched
        minutesWatched
        meanScore
      }
    }
  }
}
''';

  static const String _viewerTrackedIdsQuery = r'''
query ViewerTrackedIds($userId: Int) {
  MediaListCollection(
    userId: $userId,
    type: ANIME,
    status_in: [CURRENT, PLANNING, PAUSED, DROPPED, COMPLETED, REPEATING]
  ) {
    lists {
      entries {
        media {
          idMal
        }
      }
    }
  }
}
''';

  static const String _viewerTrackedAnimeQuery = r'''
query ViewerTrackedAnime($userId: Int) {
  MediaListCollection(
    userId: $userId,
    type: ANIME,
    status_in: [CURRENT, PLANNING, PAUSED, DROPPED, COMPLETED, REPEATING]
  ) {
    lists {
      entries {
        updatedAt
        status
        media {
          idMal
          title {
            userPreferred
            english
            romaji
          }
          bannerImage
          coverImage {
            large
          }
          averageScore
          startDate {
            year
          }
        }
      }
    }
  }
}
''';

  static const String _viewerPlanningQuery = r'''
query ViewerPlanning($userId: Int) {
  Page(page: 1, perPage: 50) {
    mediaList(userId: $userId, type: ANIME, status: PLANNING, sort: UPDATED_TIME_DESC) {
      media {
        id
        idMal
        title {
          userPreferred
          english
          romaji
        }
        coverImage {
          large
        }
        averageScore
        episodes
        startDate {
          year
        }
      }
    }
  }
}
''';

  static const String _viewerActivitiesQuery = r'''
query ViewerActivities($userId: Int) {
  Page(page: 1, perPage: 20) {
    viewerActivities: activities(userId: $userId, type: ANIME_LIST, sort: ID_DESC) {
      ... on ListActivity {
        id
        status
        progress
        createdAt
        user {
          name
          avatar {
            large
            medium
          }
        }
        media {
          id
          title {
            userPreferred
          }
          coverImage {
            large
          }
        }
      }
    }
    followingActivities: activities(isFollowing: true, type: ANIME_LIST, sort: ID_DESC) {
      ... on ListActivity {
        id
        status
        progress
        createdAt
        user {
          name
          avatar {
            large
            medium
          }
        }
        media {
          id
          title {
            userPreferred
          }
          coverImage {
            large
          }
        }
      }
    }
  }
}
''';

  static const String _mediaByMalIdQuery = r'''
query MediaByMalId($malId: Int) {
  Media(idMal: $malId, type: ANIME) {
    id
    episodes
  }
}
''';

  static const String _mediaByMalIdWithEntryQuery = r'''
query MediaByMalIdWithEntry($malId: Int) {
  Media(idMal: $malId, type: ANIME) {
    id
    episodes
    mediaListEntry {
      id
      status
    }
  }
}
''';

  static const String _artworkByMalIdsQuery = r'''
query ArtworkByMalIds($ids: [Int], $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    media(type: ANIME, idMal_in: $ids) {
      idMal
      coverImage {
        large
      }
      bannerImage
    }
  }
}
''';

  static const String _mediaListEntryByMediaQuery = r'''
query MediaListEntryByMedia($mediaId: Int) {
  MediaList(mediaId: $mediaId, type: ANIME) {
    id
    progress
    status
    customLists(asArray: true)
  }
}
''';

  static const String _airingScheduleRangeQuery = r'''
query AiringScheduleRange($page: Int, $from: Int, $to: Int) {
  Page(page: $page, perPage: 50) {
    pageInfo {
      hasNextPage
    }
    airingSchedules(
      airingAt_greater: $from
      airingAt_lesser: $to
      sort: TIME
    ) {
      airingAt
      episode
      media {
        idMal
        episodes
        averageScore
        title {
          userPreferred
          english
          romaji
        }
        coverImage {
          large
        }
      }
    }
  }
}
''';

  static const String _animeSearchQuery = r'''
query AnimeSearch(
  $page: Int,
  $perPage: Int,
  $search: String,
  $sort: [MediaSort],
  $genreIn: [String],
  $statusIn: [MediaStatus],
  $formatIn: [MediaFormat],
  $season: MediaSeason,
  $seasonYear: Int,
  $startDateGreater: FuzzyDateInt,
  $startDateLesser: FuzzyDateInt
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      total
      lastPage
      hasNextPage
    }
    media(
      type: ANIME,
      search: $search,
      sort: $sort,
      genre_in: $genreIn,
      status_in: $statusIn,
      format_in: $formatIn,
      season: $season,
      seasonYear: $seasonYear,
      startDate_greater: $startDateGreater,
      startDate_lesser: $startDateLesser,
      isAdult: false
    ) {
      idMal
      title {
        userPreferred
        english
        romaji
      }
      coverImage {
        large
      }
      bannerImage
      averageScore
      episodes
      status
      format
      genres
      startDate {
        year
        month
        day
      }
      description(asHtml: false)
    }
  }
}
''';

  static const String _relatedAnimeByMalIdQuery = r'''
query RelatedAnimeByMalId($malId: Int) {
  Media(idMal: $malId, type: ANIME) {
    relations {
      edges {
        relationType
        node {
          type
          idMal
          format
          isAdult
          title {
            userPreferred
            english
            romaji
          }
          coverImage {
            large
          }
          bannerImage
          averageScore
          startDate {
            year
            month
            day
          }
        }
      }
    }
  }
}
''';

  final Map<int, List<String>> _genreLabelsByMalId = <int, List<String>>{};
  final Map<int, String?> _statusByMalId = <int, String?>{};
  final Map<String, _CachedSearchPage> _searchPageCache = {};
  final Map<int, ({String? posterPath, String? backdropPath})?>
  _artworkByMalIdCache = <int, ({String? posterPath, String? backdropPath})?>{};

  static const String _saveMediaListEntryMutation = r'''
mutation SaveMediaListEntry($id: Int, $mediaId: Int, $status: MediaListStatus, $progress: Int, $customLists: [String]) {
  SaveMediaListEntry(id: $id, mediaId: $mediaId, status: $status, progress: $progress, customLists: $customLists) {
    id
    status
    progress
    customLists(asArray: true)
  }
}
''';

  static const String _deleteMediaListEntryMutation = r'''
mutation DeleteMediaListEntry($id: Int) {
  DeleteMediaListEntry(id: $id) {
    deleted
  }
}
''';

  Future<void> saveSessionCookie(String cookieHeader) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(anilistSessionCookieKey, cookieHeader.trim());
  }

  Future<void> saveAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(anilistAccessTokenKey, accessToken.trim());
  }

  Future<String?> getSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(anilistSessionCookieKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(anilistAccessTokenKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<Map<String, dynamic>?> getViewerProfile() async {
    final headers = await _buildAuthHeaders();
    if (headers.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.post<dynamic>(
        '',
        data: const {'query': _viewerQuery, 'variables': <String, dynamic>{}},
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data is! Map) return null;

      final typed = Map<String, dynamic>.from(data);
      final errors = typed['errors'];
      if (errors is List && errors.isNotEmpty) return null;

      final payload = typed['data'];
      if (payload is! Map) return null;

      final viewer = payload['Viewer'];
      if (viewer is! Map) return null;

      return Map<String, dynamic>.from(viewer);
    } on DioException {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final viewer = await getViewerProfile();
    return viewer != null;
  }

  Future<SearchResults> searchAnime(
    String query, {
    int page = 1,
    String? language,
    String? sortBy,
    List<String>? genreLabels,
    List<String>? statuses,
    List<String>? formats,
    String? season,
    int? startYear,
    int? endYear,
    double? minScore,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const SearchResults(
        page: 0,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }

    return _queryAnimePage(
      page: page,
      search: normalizedQuery,
      sortBy: sortBy,
      genreLabels: genreLabels,
      statuses: statuses,
      formats: formats,
      season: season,
      startYear: startYear,
      endYear: endYear,
      minScore: minScore,
      language: language,
    );
  }

  Future<SearchResults> browseAnime({
    int page = 1,
    String? language,
    String? sortBy,
    List<String>? genreLabels,
    List<String>? statuses,
    List<String>? formats,
    String? season,
    int? startYear,
    int? endYear,
    double? minScore,
  }) async {
    return _queryAnimePage(
      page: page,
      search: null,
      sortBy: sortBy,
      genreLabels: genreLabels,
      statuses: statuses,
      formats: formats,
      season: season,
      startYear: startYear,
      endYear: endYear,
      minScore: minScore,
      language: language,
    );
  }

  Future<List<SearchResult>> getRelatedAnimeByMalId(int malId) async {
    if (malId <= 0) return const [];

    try {
      final response = await _dio.post<dynamic>(
        '',
        data: {
          'query': _relatedAnimeByMalIdQuery,
          'variables': {'malId': malId},
        },
      );

      final data = response.data;
      if (data is! Map) return const [];

      final typed = Map<String, dynamic>.from(data);
      final errors = typed['errors'];
      if (errors is List && errors.isNotEmpty) return const [];

      final payload = typed['data'];
      if (payload is! Map) return const [];

      final media = payload['Media'];
      if (media is! Map) return const [];

      final relations = media['relations'];
      if (relations is! Map) return const [];

      final edges = relations['edges'];
      if (edges is! List) return const [];

      const openableFormats = <String>{
        'TV',
        'TV_SHORT',
        'MOVIE',
        'OVA',
        'ONA',
        'SPECIAL',
      };

      final results = <SearchResult>[];
      final seenMalIds = <int>{};

      for (final edgeRaw in edges.whereType<Map>()) {
        final edge = Map<String, dynamic>.from(edgeRaw);
        final node = edge['node'];
        if (node is! Map) continue;
        final nodeMap = Map<String, dynamic>.from(node);

        final nodeType = nodeMap['type']?.toString().toUpperCase();
        if (nodeType != 'ANIME') continue;

        final relatedMalId = (nodeMap['idMal'] as num?)?.toInt();
        if (relatedMalId == null || relatedMalId <= 0) continue;
        if (relatedMalId == malId || !seenMalIds.add(relatedMalId)) continue;

        final format = nodeMap['format']?.toString().toUpperCase();
        if (format == null || !openableFormats.contains(format)) continue;

        final titleObj = nodeMap['title'];
        final titleMap = titleObj is Map
            ? Map<String, dynamic>.from(titleObj)
            : const <String, dynamic>{};
        final title =
            (titleMap['userPreferred'] ??
                    titleMap['english'] ??
                    titleMap['romaji'] ??
                    'Unknown')
                .toString();

        final coverObj = nodeMap['coverImage'];
        final coverMap = coverObj is Map
            ? Map<String, dynamic>.from(coverObj)
            : const <String, dynamic>{};

        final firstAirDate = _toIsoDate(nodeMap['startDate']);

        results.add(
          SearchResult(
            adult: nodeMap['isAdult'] == true,
            id: relatedMalId,
            title: title,
            name: title,
            originalLanguage: 'ja',
            mediaType: _mapAniListFormatToMediaType(format),
            releaseDate: firstAirDate,
            firstAirDate: firstAirDate,
            posterPath: coverMap['large']?.toString(),
            backdropPath: nodeMap['bannerImage']?.toString(),
            overview: null,
            voteAverage:
                ((nodeMap['averageScore'] as num?)?.toDouble() ?? 0) > 0
                ? ((nodeMap['averageScore'] as num).toDouble() / 10.0)
                : null,
          ),
        );
      }

      int releaseKey(SearchResult item) {
        final raw = item.firstAirDate ?? item.releaseDate;
        if (raw == null || raw.length < 10) return 99999999;
        final digits = raw.replaceAll('-', '');
        return int.tryParse(digits) ?? 99999999;
      }

      results.sort((a, b) {
        final dateCmp = releaseKey(a).compareTo(releaseKey(b));
        if (dateCmp != 0) return dateCmp;
        final titleA = (a.title ?? a.name ?? '').toLowerCase();
        final titleB = (b.title ?? b.name ?? '').toLowerCase();
        return titleA.compareTo(titleB);
      });

      return results;
    } on DioException {
      return const [];
    }
  }

  List<String> getCachedGenreLabels(int malId) =>
      List<String>.from(_genreLabelsByMalId[malId] ?? const <String>[]);

  String? getCachedStatus(int malId) => _statusByMalId[malId];

  Future<({String? posterPath, String? backdropPath})?> getArtworkByMalId(
    int malId,
  ) async {
    if (malId <= 0) return null;
    final map = await getArtworkByMalIds(<int>[malId]);
    return map[malId];
  }

  Future<Map<int, ({String? posterPath, String? backdropPath})>>
  getArtworkByMalIds(Iterable<int> malIds) async {
    final normalized = malIds.where((id) => id > 0).toSet().toList()..sort();
    if (normalized.isEmpty) {
      return const <int, ({String? posterPath, String? backdropPath})>{};
    }

    final pending = normalized
        .where((id) => !_artworkByMalIdCache.containsKey(id))
        .toList(growable: false);

    for (final chunk in _chunkIntList(pending, 50)) {
      try {
        final response = await _dio.post<dynamic>(
          '',
          data: {
            'query': _artworkByMalIdsQuery,
            'variables': {'ids': chunk, 'page': 1, 'perPage': chunk.length},
          },
        );

        final data = response.data;
        if (data is! Map) continue;

        final typed = Map<String, dynamic>.from(data);
        final errors = typed['errors'];
        if (errors is List && errors.isNotEmpty) continue;

        final payload = typed['data'];
        if (payload is! Map) continue;

        final pageMap = payload['Page'];
        if (pageMap is! Map) continue;

        final mediaList = pageMap['media'];
        final foundIds = <int>{};
        if (mediaList is List) {
          for (final mediaRaw in mediaList.whereType<Map>()) {
            final media = Map<String, dynamic>.from(mediaRaw);
            final id = (media['idMal'] as num?)?.toInt();
            if (id == null || id <= 0) continue;
            foundIds.add(id);

            final coverObj = media['coverImage'];
            final coverMap = coverObj is Map
                ? Map<String, dynamic>.from(coverObj)
                : const <String, dynamic>{};
            final posterPath = coverMap['large']?.toString();
            final backdropPath = media['bannerImage']?.toString();

            _artworkByMalIdCache[id] = (
              posterPath: posterPath,
              backdropPath: backdropPath,
            );
          }
        }

        for (final id in chunk) {
          if (!_artworkByMalIdCache.containsKey(id) && !foundIds.contains(id)) {
            _artworkByMalIdCache[id] = null;
          }
        }
      } on DioException {
        // Best-effort enrichment only.
      }
    }

    final out = <int, ({String? posterPath, String? backdropPath})>{};
    for (final id in normalized) {
      final artwork = _artworkByMalIdCache[id];
      if (artwork != null) out[id] = artwork;
    }
    return out;
  }

  Iterable<List<int>> _chunkIntList(List<int> source, int chunkSize) sync* {
    if (chunkSize <= 0) {
      yield source;
      return;
    }
    for (var i = 0; i < source.length; i += chunkSize) {
      final end = (i + chunkSize < source.length)
          ? i + chunkSize
          : source.length;
      yield source.sublist(i, end);
    }
  }

  Future<SearchResults> _queryAnimePage({
    required int page,
    required String? search,
    required String? sortBy,
    required List<String>? genreLabels,
    required List<String>? statuses,
    required List<String>? formats,
    required String? season,
    required int? startYear,
    required int? endYear,
    required double? minScore,
    required String? language,
  }) async {
    final normalizedSort = _mapSortToAniList(sortBy);
    final normalizedStatuses = _mapStatusesToAniList(statuses);
    final normalizedFormats = _mapFormatsToAniList(formats);
    final normalizedSeason = _mapSeasonToAniList(season);
    final genres =
        (genreLabels ?? const <String>[])
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final startDateGreater = startYear != null
        ? (startYear * 10000 + 101)
        : null;
    final startDateLesser = endYear != null ? (endYear * 10000 + 1231) : null;
    final seasonYear = normalizedSeason != null ? startYear : null;

    final cacheKey =
        'anilist_anime_${search ?? 'browse'}_${page}_${normalizedSort.join('-')}_${normalizedStatuses.join('-')}_${normalizedFormats.join('-')}_${genres.join('|')}_${normalizedSeason ?? 'none'}_${seasonYear ?? 'none'}_${startDateGreater ?? 'none'}_${startDateLesser ?? 'none'}_${minScore ?? 'none'}_${language ?? 'all'}';

    // In-memory cache with TTL to avoid re-querying same pages frequently.
    final cached = _searchPageCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }

    final response = await _dio.post<dynamic>(
      '',
      data: {
        'query': _animeSearchQuery,
        'variables': {
          'page': page,
          'perPage': 25,
          'search': search,
          'sort': normalizedSort,
          'genreIn': genres.isEmpty ? null : genres,
          'statusIn': normalizedStatuses.isEmpty ? null : normalizedStatuses,
          'formatIn': normalizedFormats.isEmpty ? null : normalizedFormats,
          'season': normalizedSeason,
          'seasonYear': seasonYear,
          'startDateGreater': normalizedSeason != null
              ? null
              : startDateGreater,
          'startDateLesser': normalizedSeason != null ? null : startDateLesser,
        },
      },
    );

    final data = response.data;
    if (data is! Map) {
      return const SearchResults(
        page: 0,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }

    final typed = Map<String, dynamic>.from(data);
    final errors = typed['errors'];
    if (errors is List && errors.isNotEmpty) {
      return const SearchResults(
        page: 0,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }

    final payload = typed['data'];
    if (payload is! Map) {
      return const SearchResults(
        page: 0,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }

    final pageMap = payload['Page'];
    if (pageMap is! Map) {
      return const SearchResults(
        page: 0,
        results: [],
        totalPages: 0,
        totalResults: 0,
      );
    }

    final pageInfo = pageMap['pageInfo'];
    final pageInfoMap = pageInfo is Map
        ? Map<String, dynamic>.from(pageInfo)
        : const <String, dynamic>{};

    final mediaList = pageMap['media'];
    final results = <SearchResult>[];
    if (mediaList is List) {
      for (final raw in mediaList.whereType<Map>()) {
        final media = Map<String, dynamic>.from(raw);
        final malId = (media['idMal'] as num?)?.toInt();
        if (malId == null || malId <= 0) continue;

        final titleObj = media['title'];
        final titleMap = titleObj is Map
            ? Map<String, dynamic>.from(titleObj)
            : const <String, dynamic>{};
        final title =
            (titleMap['userPreferred'] ??
                    titleMap['english'] ??
                    titleMap['romaji'] ??
                    'Unknown')
                .toString();

        final coverObj = media['coverImage'];
        final coverMap = coverObj is Map
            ? Map<String, dynamic>.from(coverObj)
            : const <String, dynamic>{};

        final genresRaw = media['genres'];
        final genreList = genresRaw is List
            ? genresRaw.whereType<String>().toList(growable: false)
            : const <String>[];

        _genreLabelsByMalId[malId] = genreList;
        _statusByMalId[malId] = media['status']?.toString();

        final averageScore = (media['averageScore'] as num?)?.toDouble();
        final scoreOutOf10 = averageScore != null ? averageScore / 10.0 : null;
        if (minScore != null &&
            scoreOutOf10 != null &&
            scoreOutOf10 < minScore) {
          continue;
        }

        results.add(
          SearchResult(
            id: malId,
            title: title,
            name: title,
            originalLanguage: 'ja',
            mediaType: _mapAniListFormatToMediaType(
              media['format']?.toString(),
            ),
            firstAirDate: _toIsoDate(media['startDate']),
            posterPath: coverMap['large']?.toString(),
            backdropPath: media['bannerImage']?.toString(),
            overview: media['description']?.toString(),
            voteAverage: scoreOutOf10,
          ),
        );
      }
    }

    final totalPages =
        (pageInfoMap['lastPage'] as num?)?.toInt() ?? (results.isEmpty ? 0 : 1);
    final totalResults =
        (pageInfoMap['total'] as num?)?.toInt() ?? results.length;

    final out = SearchResults(
      page: page,
      results: results,
      totalPages: totalPages,
      totalResults: totalResults,
    );

    _searchPageCache[cacheKey] = _CachedSearchPage(out);
    // Prune old entries if cache grows too large.
    if (_searchPageCache.length > 100) {
      _searchPageCache.removeWhere((_, v) => v.isExpired);
    }

    return out;
  }

  List<String> _mapSortToAniList(String? sortBy) {
    switch ((sortBy ?? '').trim().toLowerCase()) {
      case 'rating':
      case 'score':
        return const ['SCORE_DESC'];
      case 'newest':
      case 'year':
        return const ['START_DATE_DESC'];
      case 'az':
      case 'title':
        return const ['TITLE_ROMAJI'];
      case 'airing_now':
        return const ['TRENDING_DESC'];
      case 'popularity':
      default:
        return const ['POPULARITY_DESC'];
    }
  }

  List<String> _mapStatusesToAniList(List<String>? statuses) {
    if (statuses == null || statuses.isEmpty) return const [];
    final result = <String>[];
    for (final status in statuses) {
      final mapped = _mapSingleStatusToAniList(status);
      if (mapped != null) result.add(mapped);
    }
    return result;
  }

  String? _mapSingleStatusToAniList(String status) {
    switch (status.trim().toLowerCase()) {
      case 'airing':
      case 'releasing':
        return 'RELEASING';
      case 'completed':
      case 'finished':
        return 'FINISHED';
      case 'upcoming':
      case 'not_yet_released':
        return 'NOT_YET_RELEASED';
      default:
        return null;
    }
  }

  List<String> _mapFormatsToAniList(List<String>? formats) {
    if (formats == null || formats.isEmpty) return const [];
    final result = <String>[];
    for (final format in formats) {
      final mapped = _mapSingleFormatToAniList(format);
      if (mapped != null) result.add(mapped);
    }
    return result;
  }

  String? _mapSingleFormatToAniList(String format) {
    switch (format.trim().toLowerCase()) {
      case 'tv':
      case 'series':
        return 'TV';
      case 'movie':
        return 'MOVIE';
      case 'ova':
        return 'OVA';
      case 'ona':
        return 'ONA';
      case 'special':
        return 'SPECIAL';
      default:
        return null;
    }
  }

  String? _mapSeasonToAniList(String? season) {
    switch ((season ?? '').trim().toLowerCase()) {
      case 'winter':
        return 'WINTER';
      case 'spring':
        return 'SPRING';
      case 'summer':
        return 'SUMMER';
      case 'fall':
        return 'FALL';
      default:
        return null;
    }
  }

  String _mapAniListFormatToMediaType(String? format) {
    switch ((format ?? '').trim().toUpperCase()) {
      case 'MOVIE':
        return 'movie';
      case 'OVA':
        return 'ova';
      case 'ONA':
        return 'ona';
      case 'SPECIAL':
        return 'special';
      default:
        return 'tv';
    }
  }

  String? _toIsoDate(dynamic startDateRaw) {
    if (startDateRaw is! Map) return null;
    final startDate = Map<String, dynamic>.from(startDateRaw);
    final year = (startDate['year'] as num?)?.toInt();
    if (year == null || year <= 0) return null;
    final month = ((startDate['month'] as num?)?.toInt() ?? 1).clamp(1, 12);
    final day = ((startDate['day'] as num?)?.toInt() ?? 1).clamp(1, 31);
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$year-$mm-$dd';
  }

  Future<List<Map<String, dynamic>>> getAiringScheduleRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day);
    // AniList uses strict greater/lesser comparisons; expand by 1 second to include edges.
    final from = (startUtc.millisecondsSinceEpoch ~/ 1000) - 1;
    final to = (endUtc.millisecondsSinceEpoch ~/ 1000) + 1;
    if (to <= from) return const [];

    final rows = <Map<String, dynamic>>[];
    var page = 1;
    var hasNextPage = true;

    while (hasNextPage) {
      try {
        final response = await _dio.post<dynamic>(
          '',
          data: {
            'query': _airingScheduleRangeQuery,
            'variables': {'page': page, 'from': from, 'to': to},
          },
        );

        final data = response.data;
        if (data is! Map) break;
        final typed = Map<String, dynamic>.from(data);
        final errors = typed['errors'];
        if (errors is List && errors.isNotEmpty) break;

        final payload = typed['data'];
        if (payload is! Map) break;
        final pageMap = payload['Page'];
        if (pageMap is! Map) break;

        final pageInfo = pageMap['pageInfo'];
        if (pageInfo is Map) {
          hasNextPage = pageInfo['hasNextPage'] == true;
        } else {
          hasNextPage = false;
        }

        final schedules = pageMap['airingSchedules'];
        if (schedules is List) {
          for (final item in schedules.whereType<Map>()) {
            final map = Map<String, dynamic>.from(item);
            final mediaObj = map['media'];
            if (mediaObj is! Map) continue;
            final media = Map<String, dynamic>.from(mediaObj);

            final malId = (media['idMal'] as num?)?.toInt();
            final airingAt = (map['airingAt'] as num?)?.toInt();
            if (malId == null ||
                malId <= 0 ||
                airingAt == null ||
                airingAt <= 0) {
              continue;
            }

            final titleObj = media['title'];
            final titleMap = titleObj is Map
                ? Map<String, dynamic>.from(titleObj)
                : const <String, dynamic>{};
            final title =
                (titleMap['userPreferred'] ??
                        titleMap['english'] ??
                        titleMap['romaji'] ??
                        'Unknown')
                    .toString();

            final coverObj = media['coverImage'];
            final coverMap = coverObj is Map
                ? Map<String, dynamic>.from(coverObj)
                : const <String, dynamic>{};

            final averageScore = (media['averageScore'] as num?)?.toDouble();

            rows.add({
              'malid': malId,
              'title': title,
              'picture': coverMap['large']?.toString(),
              'time': airingAt,
              'lastep': (map['episode'] as num?)?.toInt() ?? 0,
              'totalep': (media['episodes'] as num?)?.toInt(),
              'score': averageScore != null ? averageScore / 10 : null,
            });
          }
        }
      } on DioException {
        break;
      }

      page++;
      if (page > 20) break;
    }

    return rows;
  }

  Future<List<Map<String, dynamic>>> getViewerActivities() async {
    final viewer = await getViewerProfile();
    final userId = viewer?['id'];
    if (userId is! int) {
      return const [];
    }

    final headers = await _buildAuthHeaders();
    if (headers.isEmpty) {
      return const [];
    }

    try {
      final response = await _dio.post<dynamic>(
        '',
        data: {
          'query': _viewerActivitiesQuery,
          'variables': {'userId': userId},
        },
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data is! Map) return const [];

      final typed = Map<String, dynamic>.from(data);
      final errors = typed['errors'];
      if (errors is List && errors.isNotEmpty) return const [];

      final payload = typed['data'];
      if (payload is! Map) return const [];

      final page = payload['Page'];
      if (page is! Map) return const [];

      final ownActivities = page['viewerActivities'];
      final followingActivities = page['followingActivities'];

      final merged = <Map<String, dynamic>>[];
      if (ownActivities is List) {
        merged.addAll(
          ownActivities.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
      }
      if (followingActivities is List) {
        merged.addAll(
          followingActivities.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
      }

      final dedupedById = <int, Map<String, dynamic>>{};
      for (final item in merged) {
        final id = (item['id'] as num?)?.toInt();
        if (id == null || id <= 0) continue;
        dedupedById[id] = item;
      }

      final list = dedupedById.values.toList()
        ..sort((a, b) {
          final aId = (a['id'] as num?)?.toInt() ?? 0;
          final bId = (b['id'] as num?)?.toInt() ?? 0;
          return bId.compareTo(aId);
        });

      return list.length > 20 ? list.sublist(0, 20) : list;
    } on DioException {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> getViewerPlanningAnime() async {
    final viewer = await getViewerProfile();
    final userId = viewer?['id'];
    if (userId is! int) {
      return const [];
    }

    final headers = await _buildAuthHeaders();
    if (headers.isEmpty) {
      return const [];
    }

    try {
      final response = await _dio.post<dynamic>(
        '',
        data: {
          'query': _viewerPlanningQuery,
          'variables': {'userId': userId},
        },
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data is! Map) return const [];

      final typed = Map<String, dynamic>.from(data);
      final errors = typed['errors'];
      if (errors is List && errors.isNotEmpty) return const [];

      final payload = typed['data'];
      if (payload is! Map) return const [];

      final page = payload['Page'];
      if (page is! Map) return const [];

      final mediaList = page['mediaList'];
      if (mediaList is! List) return const [];

      final result = <Map<String, dynamic>>[];
      for (final row in mediaList.whereType<Map>()) {
        final media = row['media'];
        if (media is! Map) continue;

        final mediaTyped = Map<String, dynamic>.from(media);
        final malId = (mediaTyped['idMal'] as num?)?.toInt();
        if (malId == null || malId <= 0) continue;

        final titleObj = mediaTyped['title'];
        final coverObj = mediaTyped['coverImage'];
        final startObj = mediaTyped['startDate'];

        final titleMap = titleObj is Map
            ? Map<String, dynamic>.from(titleObj)
            : const <String, dynamic>{};
        final coverMap = coverObj is Map
            ? Map<String, dynamic>.from(coverObj)
            : const <String, dynamic>{};
        final startMap = startObj is Map
            ? Map<String, dynamic>.from(startObj)
            : const <String, dynamic>{};

        final title =
            (titleMap['userPreferred'] ??
                    titleMap['english'] ??
                    titleMap['romaji'] ??
                    'Unknown')
                .toString();

        final year = (startMap['year'] as num?)?.toInt();
        final firstAirDate = year != null ? '$year-01-01' : null;

        result.add({
          'id': malId,
          'title': title,
          'name': title,
          'poster_path': coverMap['large']?.toString(),
          'vote_average':
              ((mediaTyped['averageScore'] as num?)?.toDouble() ?? 0) / 10,
          'first_air_date': firstAirDate,
          'media_type': 'tv',
          'adult': false,
        });
      }

      return result;
    } on DioException {
      return const [];
    }
  }

  Future<Set<int>> getViewerTrackedAnimeIds() async {
    final viewer = await getViewerProfile();
    final userId = viewer?['id'];
    if (userId is! int) {
      return <int>{};
    }

    final headers = await _buildAuthHeaders();
    if (headers.isEmpty) {
      return <int>{};
    }

    try {
      final response = await _dio.post<dynamic>(
        '',
        data: {
          'query': _viewerTrackedIdsQuery,
          'variables': {'userId': userId},
        },
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data is! Map) return <int>{};

      final typed = Map<String, dynamic>.from(data);
      final errors = typed['errors'];
      if (errors is List && errors.isNotEmpty) return <int>{};

      final payload = typed['data'];
      if (payload is! Map) return <int>{};

      final collection = payload['MediaListCollection'];
      if (collection is! Map) return <int>{};

      final lists = collection['lists'];
      if (lists is! List) return <int>{};

      final ids = <int>{};
      for (final list in lists.whereType<Map>()) {
        final entries = list['entries'];
        if (entries is! List) continue;

        for (final entry in entries.whereType<Map>()) {
          final media = entry['media'];
          if (media is! Map) continue;
          final malId = (media['idMal'] as num?)?.toInt();
          if (malId != null && malId > 0) {
            ids.add(malId);
          }
        }
      }

      return ids;
    } on DioException {
      return <int>{};
    }
  }

  Future<List<Map<String, dynamic>>> getViewerTrackedAnime() async {
    final viewer = await getViewerProfile();
    final userId = viewer?['id'];
    if (userId is! int) {
      return const [];
    }

    final headers = await _buildAuthHeaders();
    if (headers.isEmpty) {
      return const [];
    }

    try {
      final response = await _dio.post<dynamic>(
        '',
        data: {
          'query': _viewerTrackedAnimeQuery,
          'variables': {'userId': userId},
        },
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data is! Map) return const [];

      final typed = Map<String, dynamic>.from(data);
      final errors = typed['errors'];
      if (errors is List && errors.isNotEmpty) return const [];

      final payload = typed['data'];
      if (payload is! Map) return const [];

      final collection = payload['MediaListCollection'];
      if (collection is! Map) return const [];

      final lists = collection['lists'];
      if (lists is! List) return const [];

      final result = <Map<String, dynamic>>[];
      final seen = <int>{};

      for (final list in lists.whereType<Map>()) {
        final entries = list['entries'];
        if (entries is! List) continue;

        for (final entry in entries.whereType<Map>()) {
          final media = entry['media'];
          if (media is! Map) continue;

          final mediaTyped = Map<String, dynamic>.from(media);
          final malId = (mediaTyped['idMal'] as num?)?.toInt();
          if (malId == null || malId <= 0 || !seen.add(malId)) continue;

          final updatedAt = (entry['updatedAt'] as num?)?.toInt();
          final updatedIso = updatedAt != null && updatedAt > 0
              ? DateTime.fromMillisecondsSinceEpoch(
                  updatedAt * 1000,
                ).toIso8601String()
              : null;

          final titleObj = mediaTyped['title'];
          final coverObj = mediaTyped['coverImage'];
          final startObj = mediaTyped['startDate'];

          final titleMap = titleObj is Map
              ? Map<String, dynamic>.from(titleObj)
              : const <String, dynamic>{};
          final coverMap = coverObj is Map
              ? Map<String, dynamic>.from(coverObj)
              : const <String, dynamic>{};
          final startMap = startObj is Map
              ? Map<String, dynamic>.from(startObj)
              : const <String, dynamic>{};

          final title =
              (titleMap['userPreferred'] ??
                      titleMap['english'] ??
                      titleMap['romaji'] ??
                      'Unknown')
                  .toString();

          final year = (startMap['year'] as num?)?.toInt();
          final firstAirDate = year != null ? '$year-01-01' : null;

          result.add({
            'id': malId,
            'status': entry['status']?.toString(),
            'title': title,
            'name': title,
            'poster_path': coverMap['large']?.toString(),
            'backdrop_path': mediaTyped['bannerImage']?.toString(),
            'vote_average':
                ((mediaTyped['averageScore'] as num?)?.toDouble() ?? 0) / 10,
            'first_air_date': firstAirDate,
            'media_type': 'tv',
            'adult': false,
            'updated_at': updatedIso,
          });
        }
      }

      return result;
    } on DioException {
      return const [];
    }
  }

  Future<bool> addToPlanningByMalId(int malId) async {
    final mediaEntryRef = await _getMediaEntryRefByMalId(malId);
    if (mediaEntryRef == null) return false;

    final currentStatus = (mediaEntryRef.entryStatus ?? '').toUpperCase();
    if (mediaEntryRef.entryId != null &&
        (currentStatus == 'PLANNING' ||
            currentStatus == 'CURRENT' ||
            currentStatus == 'REPEATING')) {
      return _saveMediaListByMediaId(
        mediaId: mediaEntryRef.mediaId,
        status: currentStatus,
      );
    }

    return _saveMediaListByMediaId(
      mediaId: mediaEntryRef.mediaId,
      status: 'PLANNING',
    );
  }

  Future<bool> removeFromTrackedByMalId(int malId) async {
    final mediaEntryRef = await _getMediaEntryRefByMalId(malId);
    if (mediaEntryRef == null) return false;

    final entryId = mediaEntryRef.entryId;
    if (entryId == null) {
      // No list entry means it is already removed from AniList.
      return true;
    }

    final payload = await _executeGraphQl(
      query: _deleteMediaListEntryMutation,
      variables: {'id': entryId},
      requireAccessToken: true,
    );
    if (payload == null) return false;

    final deleted = payload['DeleteMediaListEntry'];
    if (deleted is Map) {
      final flag = deleted['deleted'];
      if (flag is bool) return flag;
      if (flag is num) return flag.toInt() == 1;
    }
    return deleted != null;
  }

  Future<bool> updateProgressByMalId({
    required int malId,
    required int watchedEpisodes,
  }) async {
    if (watchedEpisodes <= 0) return false;

    final mediaRef = await _getMediaRefByMalId(malId);
    if (mediaRef == null) return false;

    final totalEpisodes = mediaRef.episodes;
    final cappedProgress = totalEpisodes != null && totalEpisodes > 0
        ? watchedEpisodes.clamp(0, totalEpisodes)
        : watchedEpisodes;

    final shouldComplete =
        totalEpisodes != null &&
        totalEpisodes > 0 &&
        cappedProgress >= totalEpisodes;

    return _saveMediaListByMediaId(
      mediaId: mediaRef.mediaId,
      status: shouldComplete ? 'COMPLETED' : 'CURRENT',
      progress: cappedProgress,
    );
  }

  Future<bool> markAsWatchingByMalId(int malId) async {
    if (malId <= 0) return false;

    final mediaRef = await _getMediaRefByMalId(malId);
    if (mediaRef == null) return false;

    final existing = await _getMediaListEntry(mediaRef.mediaId);
    final currentStatus = (existing?.status ?? '').trim().toUpperCase();
    if (currentStatus == 'CURRENT' || currentStatus == 'REPEATING') {
      return true;
    }

    return _saveMediaListByMediaId(
      mediaId: mediaRef.mediaId,
      status: 'CURRENT',
      progress: existing?.progress,
    );
  }

  Future<bool> updateStatusByMalId({
    required int malId,
    required String status,
    int? progress,
  }) async {
    if (malId <= 0) return false;
    if (status.trim().isEmpty) return false;

    final mediaRef = await _getMediaRefByMalId(malId);
    if (mediaRef == null) return false;

    return updateStatusByMediaId(
      mediaId: mediaRef.mediaId,
      status: status,
      progress: progress,
    );
  }

  Future<bool> updateStatusByMediaId({
    required int mediaId,
    required String status,
    int? progress,
  }) async {
    if (mediaId <= 0) return false;
    if (status.trim().isEmpty) return false;

    final existing = await _getMediaListEntry(mediaId);
    final payload = await _executeGraphQl(
      query: _saveMediaListEntryMutation,
      variables: {
        'id': existing?.id,
        'mediaId': existing?.id == null ? mediaId : null,
        'status': status.trim().toUpperCase(),
        'progress': progress ?? existing?.progress,
        'customLists': _withNamizoCustomList(existing?.customLists),
      },
      requireAccessToken: true,
    );

    if (payload == null) return false;
    final saved = payload['SaveMediaListEntry'];
    return saved is Map && (saved['id'] as num?)?.toInt() != null;
  }

  Future<AniListSyncResult> syncPlanningForMalIds(Iterable<int> malIds) async {
    final deduped = malIds
        .where((id) => id > 0)
        .toSet()
        .toList(growable: false);

    var synced = 0;
    for (var i = 0; i < deduped.length; i++) {
      final ok = await addToPlanningByMalId(deduped[i]);
      if (ok) synced++;
      if (i < deduped.length - 1) {
        await Future<void>.delayed(_syncPacingDelay);
      }
    }

    return AniListSyncResult(attempted: deduped.length, synced: synced);
  }

  Future<bool> _saveMediaListByMalId({
    required int malId,
    required String status,
    int? progress,
  }) async {
    final mediaRef = await _getMediaRefByMalId(malId);
    if (mediaRef == null) return false;
    return _saveMediaListByMediaId(
      mediaId: mediaRef.mediaId,
      status: status,
      progress: progress,
    );
  }

  Future<bool> _saveMediaListByMediaId({
    required int mediaId,
    required String status,
    int? progress,
  }) async {
    final existing = await _getMediaListEntry(mediaId);
    final payload = await _executeGraphQl(
      query: _saveMediaListEntryMutation,
      variables: {
        'id': existing?.id,
        'mediaId': existing?.id == null ? mediaId : null,
        'status': status,
        'progress': progress ?? existing?.progress,
        'customLists': _withNamizoCustomList(existing?.customLists),
      },
      requireAccessToken: true,
    );

    if (payload == null) return false;
    final saved = payload['SaveMediaListEntry'];
    return saved is Map && (saved['id'] as num?)?.toInt() != null;
  }

  Future<_AniListMediaRef?> _getMediaRefByMalId(int malId) async {
    if (malId <= 0) return null;
    final payload = await _executeGraphQl(
      query: _mediaByMalIdQuery,
      variables: {'malId': malId},
    );
    if (payload == null) return null;

    final media = payload['Media'];
    if (media is! Map) return null;

    final mediaId = (media['id'] as num?)?.toInt();
    if (mediaId == null || mediaId <= 0) return null;

    final episodes = (media['episodes'] as num?)?.toInt();
    return _AniListMediaRef(mediaId: mediaId, episodes: episodes);
  }

  Future<_AniListMediaEntryRef?> _getMediaEntryRefByMalId(int malId) async {
    if (malId <= 0) return null;
    final payload = await _executeGraphQl(
      query: _mediaByMalIdWithEntryQuery,
      variables: {'malId': malId},
      requireAccessToken: true,
    );
    if (payload == null) return null;

    final media = payload['Media'];
    if (media is! Map) return null;

    final mediaId = (media['id'] as num?)?.toInt();
    if (mediaId == null || mediaId <= 0) return null;

    final episodes = (media['episodes'] as num?)?.toInt();
    final mediaListEntry = media['mediaListEntry'];

    int? entryId;
    String? entryStatus;
    if (mediaListEntry is Map) {
      entryId = (mediaListEntry['id'] as num?)?.toInt();
      entryStatus = mediaListEntry['status']?.toString();
    }

    return _AniListMediaEntryRef(
      mediaId: mediaId,
      episodes: episodes,
      entryId: entryId,
      entryStatus: entryStatus,
    );
  }

  Future<int?> _getMediaListEntryId(int mediaId) async {
    final entry = await _getMediaListEntry(mediaId);
    return entry?.id;
  }

  Future<_AniListMediaListEntry?> _getMediaListEntry(int mediaId) async {
    final payload = await _executeGraphQl(
      query: _mediaListEntryByMediaQuery,
      variables: {'mediaId': mediaId},
      requireAccessToken: true,
    );
    if (payload == null) return null;

    final mediaList = payload['MediaList'];
    if (mediaList is! Map) return null;
    final id = (mediaList['id'] as num?)?.toInt();
    if (id == null || id <= 0) return null;
    final progress = (mediaList['progress'] as num?)?.toInt();
    final status = mediaList['status']?.toString();
    final customListsRaw = mediaList['customLists'];
    final customLists = customListsRaw is List
        ? customListsRaw
              .map((e) => e?.toString().trim())
              .whereType<String>()
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return _AniListMediaListEntry(
      id: id,
      progress: progress,
      status: status,
      customLists: customLists,
    );
  }

  List<String> _withNamizoCustomList(List<String>? existing) {
    final result = <String>[];
    final seen = <String>{};

    void addValue(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty) return;
      final key = normalized.toLowerCase();
      if (!seen.add(key)) return;
      result.add(normalized);
    }

    for (final item in existing ?? const <String>[]) {
      addValue(item);
    }
    addValue(_namizoCustomListName);
    return result;
  }

  Future<Map<String, dynamic>?> _executeGraphQl({
    required String query,
    required Map<String, dynamic> variables,
    int maxRetries = 2,
    bool requireAccessToken = false,
  }) async {
    final headers = await _buildAuthHeaders(
      requireAccessToken: requireAccessToken,
    );
    if (headers.isEmpty) return null;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _dio.post<dynamic>(
          '',
          data: {'query': query, 'variables': variables},
          options: Options(headers: headers),
        );

        if (response.statusCode == 429) {
          if (attempt >= maxRetries) return null;
          await _waitForRateLimit(response: response);
          continue;
        }

        final data = response.data;
        if (data is! Map) return null;

        final typed = Map<String, dynamic>.from(data);
        final errors = typed['errors'];
        if (errors is List && errors.isNotEmpty) {
          if (_isRateLimitedGraphQl(errors)) {
            if (attempt >= maxRetries) return null;
            await _waitForRateLimit(response: response);
            continue;
          }
          return null;
        }

        final payload = typed['data'];
        if (payload is! Map) return null;
        return Map<String, dynamic>.from(payload);
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 429 && attempt < maxRetries) {
          await _waitForRateLimit(response: e.response);
          continue;
        }
        return null;
      }
    }

    return null;
  }

  bool _isRateLimitedGraphQl(List<dynamic> errors) {
    for (final error in errors) {
      if (error is! Map) continue;
      final status = (error['status'] as num?)?.toInt();
      if (status == 429) return true;

      final message = error['message']?.toString().toLowerCase() ?? '';
      if (message.contains('rate limit') ||
          message.contains('too many requests')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _waitForRateLimit({Response<dynamic>? response}) async {
    final headerValue = response?.headers.map['retry-after'];
    final first = (headerValue != null && headerValue.isNotEmpty)
        ? headerValue.first
        : null;
    final seconds = first == null ? null : int.tryParse(first.trim());
    final delay = seconds != null && seconds > 0
        ? Duration(seconds: seconds)
        : _defaultRateLimitDelay;
    await Future<void>.delayed(delay);
  }

  Future<Map<String, dynamic>> _buildAuthHeaders({
    bool requireAccessToken = false,
  }) async {
    final sessionCookie = await getSessionCookie();
    final accessToken = await getAccessToken();

    if (requireAccessToken &&
        (accessToken == null || accessToken.trim().isEmpty)) {
      return const <String, dynamic>{};
    }

    final headers = <String, dynamic>{};
    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      headers['Cookie'] = sessionCookie;
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(anilistSessionCookieKey);
    await prefs.remove(anilistAccessTokenKey);
  }
}

class AniListSyncResult {
  const AniListSyncResult({required this.attempted, required this.synced});

  final int attempted;
  final int synced;

  int get failed => attempted - synced;
}

class _AniListMediaRef {
  const _AniListMediaRef({required this.mediaId, required this.episodes});

  final int mediaId;
  final int? episodes;
}

class _AniListMediaEntryRef {
  const _AniListMediaEntryRef({
    required this.mediaId,
    required this.episodes,
    required this.entryId,
    required this.entryStatus,
  });

  final int mediaId;
  final int? episodes;
  final int? entryId;
  final String? entryStatus;
}

class _AniListMediaListEntry {
  const _AniListMediaListEntry({
    required this.id,
    required this.progress,
    required this.status,
    required this.customLists,
  });

  final int id;
  final int? progress;
  final String? status;
  final List<String> customLists;
}

class _CachedSearchPage {
  _CachedSearchPage(this.results) : _created = DateTime.now();
  final SearchResults results;
  final DateTime _created;
  bool get isExpired => DateTime.now().difference(_created).inMinutes > 30;
}
