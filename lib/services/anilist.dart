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
