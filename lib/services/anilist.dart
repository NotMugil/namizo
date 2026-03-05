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
  static const Duration _defaultRateLimitDelay = Duration(milliseconds: 1200);
  static const Duration _syncPacingDelay = Duration(milliseconds: 700);

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

  static const String _mediaListEntryByMediaQuery = r'''
query MediaListEntryByMedia($mediaId: Int) {
  MediaList(mediaId: $mediaId, type: ANIME) {
    id
    progress
    status
  }
}
''';

  static const String _saveMediaListEntryMutation = r'''
mutation SaveMediaListEntry($id: Int, $mediaId: Int, $status: MediaListStatus, $progress: Int) {
  SaveMediaListEntry(id: $id, mediaId: $mediaId, status: $status, progress: $progress) {
    id
    status
    progress
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

      final ownActivities = page['viewerActivities'];
      final followingActivities = page['followingActivities'];

      final merged = <Map<String, dynamic>>[];
      if (ownActivities is List) {
        merged.addAll(
          ownActivities
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)),
        );
      }
      if (followingActivities is List) {
        merged.addAll(
          followingActivities
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)),
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

  Future<bool> addToPlanningByMalId(int malId) async {
    final mediaEntryRef = await _getMediaEntryRefByMalId(malId);
    if (mediaEntryRef == null) return false;

    final currentStatus = (mediaEntryRef.entryStatus ?? '').toUpperCase();
    if (mediaEntryRef.entryId != null &&
        (currentStatus == 'PLANNING' ||
            currentStatus == 'CURRENT' ||
            currentStatus == 'REPEATING')) {
      return true;
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

    final shouldComplete = totalEpisodes != null &&
        totalEpisodes > 0 &&
        cappedProgress >= totalEpisodes;

    return _saveMediaListByMediaId(
      mediaId: mediaRef.mediaId,
      status: shouldComplete ? 'COMPLETED' : 'CURRENT',
      progress: cappedProgress,
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
    final payload = await _executeGraphQl(
      query: _saveMediaListEntryMutation,
      variables: {
        'mediaId': mediaId,
        'status': status,
        'progress': progress,
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
    return _AniListMediaListEntry(id: id, progress: progress, status: status);
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
          data: {
            'query': query,
            'variables': variables,
          },
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
      if (message.contains('rate limit') || message.contains('too many requests')) {
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
  });

  final int id;
  final int? progress;
  final String? status;
}
