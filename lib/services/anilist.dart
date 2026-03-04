import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:namizo/core/configurations.dart';
import 'package:namizo/core/constants.dart';

class AniListService {
  AniListService({Dio? dio})
    : _dio = dio ??
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
    activities(userId: $userId, type: ANIME_LIST, sort: ID_DESC) {
      ... on ListActivity {
        id
        status
        progress
        createdAt
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
        data: const {
          'query': _viewerQuery,
          'variables': <String, dynamic>{},
        },
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

      final activities = page['activities'];
      if (activities is! List) return const [];

      return activities
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
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

        final titleMap =
            titleObj is Map ? Map<String, dynamic>.from(titleObj) : const <String, dynamic>{};
        final coverMap =
            coverObj is Map ? Map<String, dynamic>.from(coverObj) : const <String, dynamic>{};
        final startMap =
            startObj is Map ? Map<String, dynamic>.from(startObj) : const <String, dynamic>{};

        final title = (titleMap['userPreferred'] ??
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
          'vote_average': ((mediaTyped['averageScore'] as num?)?.toDouble() ?? 0) / 10,
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
              ? DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000)
                    .toIso8601String()
              : null;

          final titleObj = mediaTyped['title'];
          final coverObj = mediaTyped['coverImage'];
          final startObj = mediaTyped['startDate'];

          final titleMap =
              titleObj is Map ? Map<String, dynamic>.from(titleObj) : const <String, dynamic>{};
          final coverMap =
              coverObj is Map ? Map<String, dynamic>.from(coverObj) : const <String, dynamic>{};
          final startMap =
              startObj is Map ? Map<String, dynamic>.from(startObj) : const <String, dynamic>{};

          final title = (titleMap['userPreferred'] ??
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
            'vote_average': ((mediaTyped['averageScore'] as num?)?.toDouble() ?? 0) / 10,
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

  Future<Map<String, dynamic>> _buildAuthHeaders() async {
    final sessionCookie = await getSessionCookie();
    final accessToken = await getAccessToken();

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
