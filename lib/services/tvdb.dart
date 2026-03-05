import 'package:dio/dio.dart';
import 'package:namizo/core/config.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/core/defaults.dart';
import 'package:namizo/models/season_info.dart';
import 'package:namizo/core/cache/cache_service.dart';

class TvdbMetadataService {
  static const String _mappingUrl = AppConfigurations.tvdbMappingUrl;
  static const bool _artworkDebug = bool.fromEnvironment(
    'TVDB_ARTWORK_DEBUG',
    defaultValue: false,
  );

  final CacheService _cache;
  final Dio _mappingDio;
  final Dio _jikanDio;
  final Dio _tvdbDio;
  String? _token;
  Map<int, String>? _artworkTypeById;

  TvdbMetadataService(this._cache)
      : _mappingDio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ),
        _jikanDio = Dio(
          BaseOptions(
            baseUrl: AppConfigurations.jikanBaseUrl,
            connectTimeout: standardTimeout,
            receiveTimeout: standardTimeout,
            headers: {
              'User-Agent': AppConfigurations.defaultAppUserAgent,
            },
          ),
        ),
        _tvdbDio = Dio(
          BaseOptions(
            baseUrl: AppConfigurations.tvdbBaseUrl,
            connectTimeout: extendedTimeout,
            receiveTimeout: extendedTimeout,
            headers: {
              'Accept-Language': 'eng',
            },
          ),
        );

  bool get isEnabled => UserConfig.tvdbApiKey.trim().isNotEmpty;

  Future<TvdbMappingEntry?> getMappingForMalId(int malId) async {
    final cacheKey = 'tvdb_mapping_mal_$malId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final resolved = TvdbMappingEntry.fromJson(cached.cast<String, dynamic>());
      if (resolved.tvdbId > 0) return resolved;
    }

    try {
      final yamlText = await _loadMappingYaml();
      TvdbMappingEntry? parsed = _parseMappingEntry(yamlText, malId);

      if (parsed == null || parsed.tvdbId <= 0) {
        parsed = await _resolveDynamicMappingForMalId(malId);
      }

      if (parsed != null && parsed.tvdbId > 0) {
        await _cache.set(
          cacheKey,
          parsed.toJson(),
          ttl: CacheService.longCache,
        );
      }

      return parsed;
    } catch (_) {
      return null;
    }
  }

  Future<TvdbMappingEntry?> _resolveDynamicMappingForMalId(int malId) async {
    if (!isEnabled) return null;

    final profile = await _fetchMalLookupProfile(malId);
    if (profile == null || profile.titles.isEmpty) return null;

    final allCandidates = <int, _TvdbSeriesCandidate>{};
    for (final query in profile.titles.take(4)) {
      final candidates = await _searchTvdbSeries(query);
      for (final candidate in candidates) {
        allCandidates[candidate.tvdbId] = candidate;
      }
    }

    if (allCandidates.isEmpty) return null;

    _TvdbSeriesCandidate? best;
    var bestScore = double.negativeInfinity;

    for (final candidate in allCandidates.values) {
      final score = _scoreTvdbCandidate(candidate, profile);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    if (best == null || best.tvdbId <= 0 || bestScore < 58) {
      return null;
    }

    if (_artworkDebug) {
      print(
        '[TVDB][DynamicMapping] MAL $malId -> TVDB ${best.tvdbId} '
        'title="${best.name}" score=${bestScore.toStringAsFixed(2)}',
      );
    }

    return TvdbMappingEntry(
      malId: malId,
      tvdbId: best.tvdbId,
      tvdbSeason: 1,
      start: 0,
      useMapping: false,
    );
  }

  Future<_MalLookupProfile?> _fetchMalLookupProfile(int malId) async {
    try {
      final response = await _jikanDio.get('/anime/$malId/full');
      final root = response.data;
      if (root is! Map) return null;
      final data = root['data'];
      if (data is! Map) return null;

      final normalized = data.cast<String, dynamic>();
      final titles = <String>{};

      void collect(dynamic value) {
        final title = value?.toString().trim();
        if (title != null && title.isNotEmpty) {
          titles.add(title);
        }
      }

      collect(normalized['title_english']);
      collect(normalized['title']);
      collect(normalized['title_japanese']);

      final titleList = normalized['titles'];
      if (titleList is List) {
        for (final item in titleList) {
          if (item is! Map) continue;
          collect(item['title']);
        }
      }

      int? year = (normalized['year'] as num?)?.toInt();
      year ??= _extractYearFromDateString(
        (normalized['aired'] is Map)
            ? (normalized['aired'] as Map)['from']?.toString()
            : null,
      );

      if (titles.isEmpty) return null;
      return _MalLookupProfile(
        malId: malId,
        titles: titles.toList(growable: false),
        year: year,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<_TvdbSeriesCandidate>> _searchTvdbSeries(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final ready = await _ensureToken();
    if (!ready) return const [];

    final endpoints = [
      {'query': normalizedQuery, 'type': 'series'},
      {'query': normalizedQuery},
    ];

    final results = <_TvdbSeriesCandidate>[];
    final seenIds = <int>{};

    for (final params in endpoints) {
      try {
        final response = await _tvdbDio.get(
          '/search',
          queryParameters: params,
        );
        final root = response.data;
        if (root is! Map) continue;

        final data = root['data'];
        if (data is! List) continue;

        for (final row in data) {
          if (row is! Map) continue;
          final item = row.cast<String, dynamic>();
          final tvdbId =
              _toInt(item['tvdb_id']) ?? _toInt(item['id']) ?? _toInt(item['seriesId']);
          if (tvdbId == null || tvdbId <= 0 || !seenIds.add(tvdbId)) {
            continue;
          }

          final name = (item['name'] ?? item['seriesName'] ?? item['title'])
              ?.toString()
              .trim();
          if (name == null || name.isEmpty) continue;

          final year =
              _toInt(item['year']) ?? _extractYearFromDateString(item['firstAired']?.toString());

          results.add(
            _TvdbSeriesCandidate(
              tvdbId: tvdbId,
              name: name,
              year: year,
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  double _scoreTvdbCandidate(
    _TvdbSeriesCandidate candidate,
    _MalLookupProfile profile,
  ) {
    final candidateName = _normalizeComparableTitle(candidate.name);
    if (candidateName.isEmpty) return -1000;

    var bestTitleScore = -1000.0;
    for (final title in profile.titles) {
      final normalizedTitle = _normalizeComparableTitle(title);
      if (normalizedTitle.isEmpty) continue;

      var score = 0.0;
      if (candidateName == normalizedTitle) {
        score += 90;
      } else if (candidateName.contains(normalizedTitle) ||
          normalizedTitle.contains(candidateName)) {
        score += 62;
      }

      final queryTokens = _tokenizeTitle(normalizedTitle);
      final candidateTokens = _tokenizeTitle(candidateName);
      if (queryTokens.isNotEmpty && candidateTokens.isNotEmpty) {
        final intersection = queryTokens.intersection(candidateTokens).length;
        final union = queryTokens.union(candidateTokens).length;
        final jaccard = union == 0 ? 0 : intersection / union;
        score += jaccard * 60;
      }

      if (score > bestTitleScore) {
        bestTitleScore = score;
      }
    }

    var total = bestTitleScore;
    if (profile.year != null && candidate.year != null) {
      final yearDelta = (profile.year! - candidate.year!).abs();
      if (yearDelta == 0) {
        total += 20;
      } else if (yearDelta == 1) {
        total += 14;
      } else if (yearDelta <= 3) {
        total += 6;
      } else {
        total -= (yearDelta * 2).toDouble();
      }
    }

    return total;
  }

  String _normalizeComparableTitle(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _tokenizeTitle(String input) {
    return input
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .toSet();
  }

  int? _extractYearFromDateString(String? value) {
    if (value == null || value.trim().length < 4) return null;
    final match = RegExp(r'(19|20)\d{2}').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  Future<String?> getLogoUrlForMalId(int malId) async {
    final mapping = await getMappingForMalId(malId);
    if (mapping == null || mapping.tvdbId <= 0 || !isEnabled) {
      return null;
    }

    final cacheKey = 'tvdb_logo_mal_v2_$malId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final url = cached['logo'] as String?;
      return (url != null && url.isNotEmpty) ? url : null;
    }

    final series = await _fetchBestArtworkSeries(mapping.tvdbId);
    if (series == null) return null;

    final logo = _extractArtworkUrl(series, typeHints: const [
      'clearlogo',
      'logo',
      'wordmark',
    ]);

    await _cache.set(
      cacheKey,
      {'logo': logo ?? ''},
      ttl: CacheService.longCache,
    );

    return logo;
  }

  Future<String?> getClearLogoUrlForMalId(int malId) async {
    final mapping = await getMappingForMalId(malId);
    if (mapping == null || mapping.tvdbId <= 0 || !isEnabled) {
      return null;
    }

    final cacheKey = 'tvdb_clearlogo_mal_v2_$malId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final url = cached['clearlogo'] as String?;
      return (url != null && url.isNotEmpty) ? url : null;
    }

    final series = await _fetchBestArtworkSeries(
      mapping.tvdbId,
      requireClearLogo: true,
    );
    if (series == null) return null;

    final clearLogo = _extractArtworkUrlStrict(series, typeHints: const [
      'clearlogo',
      'clear_logo',
      'clear logo',
    ]);

    await _cache.set(
      cacheKey,
      {'clearlogo': clearLogo ?? ''},
      ttl: CacheService.longCache,
    );

    return clearLogo;
  }

  Future<TvdbArtworkMetadata?> getArtworkForMalId(int malId) async {
    final mapping = await getMappingForMalId(malId);
    if (mapping == null || mapping.tvdbId <= 0 || !isEnabled) {
      return null;
    }

    final cacheKey = 'tvdb_artwork_mal_v3_$malId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      return TvdbArtworkMetadata.fromJson(cached.cast<String, dynamic>());
    }

    await _getArtworkTypeMap();

    final series = await _fetchBestArtworkSeries(mapping.tvdbId);
    if (series == null) return null;

    final seasonArtwork = await _fetchSeasonArtworkForMapping(mapping);

    final surfaceArtwork = _buildSurfaceArtwork(
      series,
      seasonArtwork: seasonArtwork,
      malId: malId,
      tvdbId: mapping.tvdbId,
    );

    final artwork = TvdbArtworkMetadata(
      logoUrl: surfaceArtwork.logoUrl,
      posterUrl: surfaceArtwork.detailPosterUrl,
      bannerUrl: surfaceArtwork.detailBackdropUrl,
      carouselBackdropUrl: surfaceArtwork.carouselBackdropUrl,
    );

    await _cache.set(
      cacheKey,
      artwork.toJson(),
      ttl: CacheService.longCache,
    );

    return artwork;
  }

  Future<String?> getCarouselBackdropUrlForMalId(int malId) async {
    final artwork = await getArtworkForMalId(malId);
    return artwork?.carouselBackdropUrl;
  }

  Future<String?> getNoTextPosterUrlForMalId(int malId) async {
    final mapping = await getMappingForMalId(malId);
    if (mapping == null || mapping.tvdbId <= 0 || !isEnabled) {
      return null;
    }

    await _getArtworkTypeMap();

    final series = await _fetchBestArtworkSeries(mapping.tvdbId);
    if (series == null) return null;

    final poster = _selectArtworkUrl(
      series,
      policy: const _ArtworkSelectionPolicy(
        mode: 'carousel-poster-no-text-direct',
        typeHints: ['poster', 'cover', 'keyart'],
        targetAspectRatio: 2 / 3,
        preferPortrait: true,
        preferNoText: true,
        strictNoText: true,
      ),
    );

    return poster;
  }

  Future<List<TvdbSimilarSeries>> getSimilarSeriesForMalId(int malId) async {
    if (!isEnabled) return const [];

    final mapping = await getMappingForMalId(malId);
    if (mapping == null || mapping.tvdbId <= 0) return const [];

    final cacheKey = 'tvdb_similar_series_mal_v1_$malId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final rows = cached['items'];
      if (rows is List) {
        return rows
            .whereType<Map>()
            .map((row) => TvdbSimilarSeries.fromJson(row.cast<String, dynamic>()))
            .toList(growable: false);
      }
    }

    final resolvedSeriesId =
        await _resolveSeriesIdFromSeasonId(mapping.tvdbId) ?? mapping.tvdbId;
    final records = await _fetchSimilarSeriesRecords(resolvedSeriesId);
    if (records.isEmpty) {
      await _cache.set(cacheKey, {'items': const []}, ttl: CacheService.mediumCache);
      return const [];
    }

    final seen = <int>{};
    final output = <TvdbSimilarSeries>[];

    for (final record in records) {
      final mapped = await _mapSimilarRecord(record);
      if (mapped == null) continue;
      if (mapped.tvdbId != null && !seen.add(mapped.tvdbId!)) continue;
      if (mapped.title.trim().isEmpty) continue;
      output.add(mapped);
      if (output.length >= 18) break;
    }

    await _cache.set(
      cacheKey,
      {'items': output.map((item) => item.toJson()).toList(growable: false)},
      ttl: CacheService.mediumCache,
    );

    return output;
  }

  Future<SeasonData> enrichSeasonData({
    required int malId,
    required int seasonNumber,
    required SeasonData fallback,
  }) async {
    if (fallback.episodes.isEmpty || !isEnabled) return fallback;

    final mapping = await getMappingForMalId(malId);
    if (mapping == null || mapping.tvdbId <= 0) return fallback;

    final cacheKey = 'tvdb_season_enriched_${malId}_$seasonNumber';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      try {
        return SeasonData.fromJson(cached.cast<String, dynamic>());
      } catch (_) {}
    }

    final targetTvdbSeason = mapping.tvdbSeason > 0 ? mapping.tvdbSeason : 1;
    final tvdbEpisodes = await _fetchSeasonEpisodes(
      mapping.tvdbId,
      targetTvdbSeason,
    );
    if (tvdbEpisodes.isEmpty) return fallback;

    final enrichedEpisodes = <EpisodeData>[];
    for (final episode in fallback.episodes) {
      final tvdbEpisodeNumber = episode.episodeNumber + mapping.start;
      final match = _findTvdbEpisode(tvdbEpisodes, tvdbEpisodeNumber);
      if (match == null) {
        enrichedEpisodes.add(episode);
        continue;
      }

      String? name = (match['name'] ?? match['episodeName']) as String?;
      String? overview = (match['overview'] ?? match['summary']) as String?;
      final image =
          (match['image'] ?? match['filename'] ?? match['thumbnail']) as String?;
      final score = (match['score'] as num?)?.toDouble();
      final runtime = (match['runtime'] as num?)?.toInt();
      final aired = (match['aired'] ?? match['airedAt'] ?? match['firstAired'])
          as String?;

      final episodeId = (match['id'] as num?)?.toInt();
      final shouldTranslate =
          _isLikelyNonEnglish(name) || _isLikelyNonEnglish(overview);
      if (episodeId != null && shouldTranslate) {
        final english = await _fetchEpisodeEnglishTranslation(episodeId);
        name = english?.name ?? name;
        overview = english?.overview ?? overview;
      }

      enrichedEpisodes.add(
        episode.copyWith(
        episodeName:
            name != null && name.trim().isNotEmpty ? name : episode.episodeName,
        overview: overview?.trim().isNotEmpty == true ? overview : episode.overview,
        stillPath: image?.trim().isNotEmpty == true ? image : episode.stillPath,
        voteAverage: score ?? episode.voteAverage,
        runtime: runtime ?? episode.runtime,
        airDate: _normalizeDate(aired) ?? episode.airDate,
        ),
      );
    }

    final enriched = SeasonData(episodes: enrichedEpisodes);
    await _cache.set(cacheKey, enriched.toJson(), ttl: CacheService.longCache);
    return enriched;
  }

  Future<String> _loadMappingYaml() async {
    const cacheKey = 'tvdb_mapping_yaml_raw';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final content = cached['content'] as String?;
      if (content != null && content.isNotEmpty) return content;
    }

    final response = await _mappingDio.get<String>(_mappingUrl);
    final body = response.data ?? '';
    if (body.isEmpty) {
      throw Exception('Failed to load TVDB mapping YAML');
    }

    await _cache.set(
      cacheKey,
      {'content': body},
      ttl: CacheService.longCache,
    );

    return body;
  }

  Future<List<Map<String, dynamic>>> _fetchSimilarSeriesRecords(int seriesId) async {
    final ready = await _ensureToken();
    if (!ready) return const [];

    final endpoints = [
      '/series/$seriesId/recommendations',
      '/series/$seriesId/similar',
      '/series/$seriesId/related',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _tvdbDio.get(endpoint);
        final rows = _extractSimilarRecords(response.data);
        if (rows.isNotEmpty) return rows;
      } catch (_) {
        continue;
      }
    }

    final extended = await _fetchSeriesExtended(seriesId);
    if (extended == null) return const [];
    return _extractSimilarRecords(extended);
  }

  List<Map<String, dynamic>> _extractSimilarRecords(dynamic raw) {
    Map<String, dynamic>? root;
    if (raw is Map<String, dynamic>) {
      root = raw;
    } else if (raw is Map) {
      root = raw.cast<String, dynamic>();
    }
    if (root == null) return const [];

    List<Map<String, dynamic>> collectFrom(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    }

    final data = root['data'];
    final directCandidates = [
      root['recommendations'],
      root['similar'],
      root['similars'],
      root['related'],
      root['relatedSeries'],
      data,
      data is Map ? data['recommendations'] : null,
      data is Map ? data['similar'] : null,
      data is Map ? data['similars'] : null,
      data is Map ? data['related'] : null,
      data is Map ? data['relatedSeries'] : null,
      data is Map ? data['series'] : null,
      data is Map ? data['items'] : null,
    ];

    for (final candidate in directCandidates) {
      final rows = collectFrom(candidate);
      if (rows.isNotEmpty) return rows;
    }

    return const [];
  }

  Future<TvdbSimilarSeries?> _mapSimilarRecord(Map<String, dynamic> raw) async {
    int? tvdbId =
        _toInt(raw['tvdb_id']) ?? _toInt(raw['id']) ?? _toInt(raw['seriesId']);
    String? title = _toCleanString(
      raw['name'] ?? raw['seriesName'] ?? raw['title'],
    );
    String? overview = _toCleanString(raw['overview'] ?? raw['summary']);
    String? image = _toCleanString(raw['image'] ?? raw['poster'] ?? raw['banner']);
    final score = (raw['score'] as num?)?.toDouble();
    int? year = _toInt(raw['year']) ?? _extractYearFromDateString(raw['firstAired']?.toString());
    int? malId = _extractMalIdFromRemoteIds(raw['remoteIds']);

    if (tvdbId != null && (title == null || title.isEmpty || image == null || image.isEmpty)) {
      final extended = await _fetchSeriesExtended(tvdbId);
      if (extended != null) {
        title ??= _toCleanString(
          extended['name'] ?? extended['seriesName'] ?? extended['title'],
        );
        overview ??= _toCleanString(extended['overview'] ?? extended['summary']);
        image ??= _extractArtworkUrl(
              extended,
              typeHints: const ['poster', 'cover', 'keyart', 'banner', 'fanart'],
            ) ??
            _extractFirstArtworkField(extended, const ['image', 'poster', 'banner']);
        year ??= _toInt(extended['year']) ??
            _extractYearFromDateString(extended['firstAired']?.toString());
        malId ??= _extractMalIdFromRemoteIds(extended['remoteIds']);
      }
    }

    if (title == null || title.isEmpty) return null;
    return TvdbSimilarSeries(
      tvdbId: tvdbId,
      malId: malId,
      sourceType: 'anime',
      title: title,
      overview: overview,
      imageUrl: image,
      score: score,
      year: year,
    );
  }

  int? _extractMalIdFromRemoteIds(dynamic remoteIdsRaw) {
    if (remoteIdsRaw is! List) return null;
    for (final row in remoteIdsRaw.whereType<Map>()) {
      final item = row.cast<String, dynamic>();
      final source = (item['sourceName'] ?? item['source'] ?? item['type'])
          ?.toString()
          .toLowerCase();
      if (source == null || !source.contains('myanimelist')) continue;

      final direct = _toInt(item['id']) ?? _toInt(item['sourceId']) ?? _toInt(item['value']);
      if (direct != null && direct > 0) return direct;

      final text = item['url']?.toString() ?? item['value']?.toString() ?? '';
      final match = RegExp(r'/anime/(\d+)').firstMatch(text);
      final parsed = match == null ? null : int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  TvdbMappingEntry? _parseMappingEntry(String yamlContent, int malId) {
    final lines = yamlContent.split('\n');

    int? currentMalId;
    int tvdbId = 0;
    int tvdbSeason = 1;
    int start = 0;
    bool useMapping = false;

    void reset() {
      tvdbId = 0;
      tvdbSeason = 1;
      start = 0;
      useMapping = false;
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('- malid:')) {
        if (currentMalId == malId) {
          return TvdbMappingEntry(
            malId: currentMalId!,
            tvdbId: tvdbId,
            tvdbSeason: tvdbSeason,
            start: start,
            useMapping: useMapping,
          );
        }

        currentMalId = int.tryParse(line.split(':').last.trim());
        reset();
        continue;
      }

      if (currentMalId != malId) continue;

      if (line.startsWith('tvdbid:')) {
        tvdbId = int.tryParse(line.split(':').last.trim()) ?? 0;
      } else if (line.startsWith('tvdbseason:')) {
        tvdbSeason = int.tryParse(line.split(':').last.trim()) ?? 1;
      } else if (line.startsWith('start:')) {
        start = int.tryParse(line.split(':').last.trim()) ?? 0;
      } else if (line.startsWith('useMapping:')) {
        useMapping = line.split(':').last.trim().toLowerCase() == 'true';
      }
    }

    if (currentMalId == malId) {
      return TvdbMappingEntry(
        malId: currentMalId!,
        tvdbId: tvdbId,
        tvdbSeason: tvdbSeason,
        start: start,
        useMapping: useMapping,
      );
    }

    return null;
  }

  Future<bool> _ensureToken() async {
    if (!isEnabled) return false;
    if (_token != null && _token!.isNotEmpty) return true;

    try {
      final body = <String, dynamic>{'apikey': UserConfig.tvdbApiKey};
      if (UserConfig.tvdbPin.trim().isNotEmpty) {
        body['pin'] = UserConfig.tvdbPin;
      }

      final response = await _tvdbDio.post('/login', data: body);
      final data = response.data;
        final root = data is Map ? Map<String, dynamic>.from(data) : null;
        final payload =
          root?['data'] is Map ? Map<String, dynamic>.from(root!['data']) : null;
        final token = payload?['token']?.toString().trim();
      if (token == null || token.isEmpty) return false;

      _token = token;
      _tvdbDio.options.headers['Authorization'] = 'Bearer $token';
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _fetchSeriesExtended(int tvdbId) async {
    final ready = await _ensureToken();
    if (!ready) return null;

    try {
      final response = await _tvdbDio.get('/series/$tvdbId/extended');
      final data = response.data;
      if (data is! Map) return null;

      final payload = data['data'];
      if (payload is! Map) return null;
      return Map<String, dynamic>.from(payload);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSeriesArtworks(int seriesId) async {
    final ready = await _ensureToken();
    if (!ready) return const [];

    final endpoints = [
      '/series/$seriesId/artworks?lang=eng',
      '/series/$seriesId/artworks',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _tvdbDio.get(endpoint);
        final data = response.data;
        if (data is! Map) continue;

        final payload = data['data'];
        if (payload is! Map) continue;

        final normalized = Map<String, dynamic>.from(payload);
        final records = _extractArtworkRecords(normalized);
        if (records.isNotEmpty) return records;
      } catch (_) {
        continue;
      }
    }

    return const [];
  }

  Future<Map<String, dynamic>?> _fetchSeasonExtended(int seasonId) async {
    final ready = await _ensureToken();
    if (!ready) return null;

    final endpoints = [
      '/seasons/$seasonId/extended',
      '/seasons/$seasonId',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _tvdbDio.get(endpoint);
        final data = response.data;
        if (data is! Map) continue;

        final payload = data['data'];
        if (payload is! Map) continue;
        return Map<String, dynamic>.from(payload);
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<TvdbArtworkMetadata?> _fetchSeasonArtworkForMapping(
    TvdbMappingEntry mapping,
  ) async {
    if (mapping.tvdbSeason <= 0) return null;

    await _getArtworkTypeMap();

    final seasonId = await _resolveSeasonIdForMapping(mapping);
    if (seasonId == null) return null;

    final season = await _fetchSeasonExtended(seasonId);
    if (season == null) return null;

    final posterUrl = _extractArtworkUrl(season, typeHints: const [
      'poster',
      'cover',
      'keyart',
    ]);
    final bannerUrl = _extractArtworkUrlStrict(season, typeHints: const [
          'banner',
          'fanart',
          'background',
        ]) ??
        _extractFirstArtworkField(season, const [
          'banner',
          'fanart',
          'background',
        ]);

    if ((posterUrl == null || posterUrl.isEmpty) &&
        (bannerUrl == null || bannerUrl.isEmpty)) {
      return null;
    }

    return TvdbArtworkMetadata(
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
    );
  }

  Future<int?> _resolveSeasonIdForMapping(TvdbMappingEntry mapping) async {
    final possibleSeriesId = await _resolveSeriesIdFromSeasonId(mapping.tvdbId);
    if (possibleSeriesId != null && possibleSeriesId > 0) {
      return _resolveSeasonIdByNumber(possibleSeriesId, mapping.tvdbSeason);
    }

    final directSeason = await _fetchSeasonExtended(mapping.tvdbId);
    if (directSeason != null) {
      final number = (directSeason['number'] as num?)?.toInt();
      if (number == null || number == mapping.tvdbSeason) {
        final id = (directSeason['id'] as num?)?.toInt();
        if (id != null && id > 0) return id;
      }

      final series = directSeason['series'];
      final nestedSeriesId =
          series is Map ? (series['id'] as num?)?.toInt() : null;
      if (nestedSeriesId != null && nestedSeriesId > 0) {
        final resolved = await _resolveSeasonIdByNumber(
          nestedSeriesId,
          mapping.tvdbSeason,
        );
        if (resolved != null) return resolved;
      }
    }

    return _resolveSeasonIdByNumber(mapping.tvdbId, mapping.tvdbSeason);
  }

  Future<int?> _resolveSeasonIdByNumber(int seriesId, int seasonNumber) async {
    final series = await _fetchSeriesExtended(seriesId);
    if (series != null) {
      final fromExtended = _extractSeasonIdFromContainer(series, seasonNumber);
      if (fromExtended != null) return fromExtended;
    }

    final ready = await _ensureToken();
    if (!ready) return null;

    final endpoints = [
      '/series/$seriesId/seasons',
      '/series/$seriesId/extended',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _tvdbDio.get(endpoint);
        final data = response.data;
        if (data is! Map) continue;
        final payload = data['data'];

        if (payload is Map) {
          final id = _extractSeasonIdFromContainer(
            payload.cast<String, dynamic>(),
            seasonNumber,
          );
          if (id != null) return id;
        }

        if (payload is List) {
          final id = _extractSeasonIdFromList(
            payload.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
            seasonNumber,
          );
          if (id != null) return id;
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  int? _extractSeasonIdFromContainer(
    Map<String, dynamic> container,
    int seasonNumber,
  ) {
    final directSeasons = container['seasons'];
    if (directSeasons is List) {
      return _extractSeasonIdFromList(
        directSeasons.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
        seasonNumber,
      );
    }

    final nestedData = container['data'];
    if (nestedData is List) {
      return _extractSeasonIdFromList(
        nestedData.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
        seasonNumber,
      );
    }

    return null;
  }

  int? _extractSeasonIdFromList(
    List<Map<String, dynamic>> seasons,
    int seasonNumber,
  ) {
    for (final season in seasons) {
      final number =
          (season['number'] as num?)?.toInt() ??
          (season['seasonNumber'] as num?)?.toInt() ??
          (season['season'] as num?)?.toInt();
      if (number != seasonNumber) continue;

      final id = (season['id'] as num?)?.toInt();
      if (id != null && id > 0) return id;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchBestArtworkSeries(
    int tvdbId, {
    bool requireClearLogo = false,
  }) async {
    final primary = await _fetchSeriesExtended(tvdbId);
    if (primary != null) {
      final directArtworks = await _fetchSeriesArtworks(tvdbId);
      if (directArtworks.isNotEmpty) {
        final existing = _extractArtworkRecords(primary);
        primary['artworks'] = [...existing, ...directArtworks];
      }
    }

    if (primary != null) {
      if (!requireClearLogo ||
          _extractArtworkUrlStrict(primary, typeHints: const [
            'clearlogo',
            'clear_logo',
            'clear logo',
          ]) !=
              null) {
        return primary;
      }
    }

    final parentSeriesId = await _resolveSeriesIdFromSeasonId(tvdbId);
    if (parentSeriesId == null || parentSeriesId == tvdbId) {
      return primary;
    }

    final parent = await _fetchSeriesExtended(parentSeriesId);
    if (parent == null) return primary;

    final parentArtworks = await _fetchSeriesArtworks(parentSeriesId);
    if (parentArtworks.isNotEmpty) {
      final existing = _extractArtworkRecords(parent);
      parent['artworks'] = [...existing, ...parentArtworks];
    }

    if (!requireClearLogo) return parent;
    final parentClearLogo = _extractArtworkUrlStrict(parent, typeHints: const [
      'clearlogo',
      'clear_logo',
      'clear logo',
    ]);
    return parentClearLogo != null ? parent : primary;
  }

  Future<int?> _resolveSeriesIdFromSeasonId(int seasonId) async {
    final ready = await _ensureToken();
    if (!ready) return null;

    final endpoints = [
      '/seasons/$seasonId/extended',
      '/seasons/$seasonId',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _tvdbDio.get(endpoint);
        final data = response.data;
        if (data is! Map) continue;

        final payload = data['data'];
        if (payload is! Map) continue;
        final normalized = Map<String, dynamic>.from(payload);

        final direct = (normalized['seriesId'] as num?)?.toInt();
        if (direct != null && direct > 0) return direct;

        final series = normalized['series'];
        if (series is Map) {
          final nested = (series['id'] as num?)?.toInt();
          if (nested != null && nested > 0) return nested;
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchSeasonEpisodes(
    int tvdbId,
    int season,
  ) async {
    final ready = await _ensureToken();
    if (!ready) return const [];

    final endpoints = [
      '/series/$tvdbId/episodes/default?season=$season',
      '/series/$tvdbId/episodes/default/$season',
      '/series/$tvdbId/episodes/$season',
      '/series/$tvdbId/episodes/official?season=$season',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _tvdbDio.get(endpoint);
        final list = _extractEpisodeList(response.data);
        if (list.isNotEmpty) return list;
      } catch (_) {
        continue;
      }
    }

    return const [];
  }

  List<Map<String, dynamic>> _extractEpisodeList(dynamic raw) {
    if (raw is! Map) return const [];

    final data = raw['data'];
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }

    if (data is Map) {
      final directEpisodes = data['episodes'];
      if (directEpisodes is List) {
        return directEpisodes
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }

      final arrayLike = data['data'];
      if (arrayLike is List) {
        return arrayLike
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    return const [];
  }

  Map<String, dynamic>? _findTvdbEpisode(
    List<Map<String, dynamic>> episodes,
    int episodeNumber,
  ) {
    for (final ep in episodes) {
      final numbers = <int?>[
        (ep['number'] as num?)?.toInt(),
        (ep['episodeNumber'] as num?)?.toInt(),
        (ep['airedEpisodeNumber'] as num?)?.toInt(),
        (ep['absoluteNumber'] as num?)?.toInt(),
      ];

      if (numbers.whereType<int>().contains(episodeNumber)) {
        return ep;
      }
    }
    return null;
  }

  String? _normalizeDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    return value.length >= 10 ? value.substring(0, 10) : null;
  }

  bool _isLikelyNonEnglish(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    return RegExp(r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF]')
        .hasMatch(text);
  }

  Future<_EpisodeEnglishTranslation?> _fetchEpisodeEnglishTranslation(
    int episodeId,
  ) async {
    final cacheKey = 'tvdb_episode_translation_eng_$episodeId';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final translation = _EpisodeEnglishTranslation.fromJson(
        cached.cast<String, dynamic>(),
      );
      if (translation.hasContent) {
        return translation;
      }
      return null;
    }

    final ready = await _ensureToken();
    if (!ready) return null;

    final endpoints = [
      '/episodes/$episodeId/translations/eng',
      '/episodes/$episodeId/translations/en',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await _tvdbDio.get(endpoint);
        final data = response.data;
        if (data is! Map) continue;

        final payload = data['data'];
        if (payload is! Map) continue;

        final normalized = Map<String, dynamic>.from(payload);
        final translation = _EpisodeEnglishTranslation(
          name: _toCleanString(
            normalized['name'] ??
                normalized['episodeName'] ??
                normalized['title'],
          ),
          overview: _toCleanString(
            normalized['overview'] ?? normalized['description'],
          ),
        );

        await _cache.set(
          cacheKey,
          translation.toJson(),
          ttl: CacheService.longCache,
        );

        if (translation.hasContent) {
          return translation;
        }
      } catch (_) {
        continue;
      }
    }

    await _cache.set(
      cacheKey,
      const _EpisodeEnglishTranslation(name: null, overview: null).toJson(),
      ttl: CacheService.mediumCache,
    );
    return null;
  }

  String? _toCleanString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  _SurfaceArtworkResult _buildSurfaceArtwork(
    Map<String, dynamic> series, {
    required TvdbArtworkMetadata? seasonArtwork,
    required int malId,
    required int tvdbId,
  }) {
    final logoUrl = _selectArtworkUrl(
      series,
      policy: const _ArtworkSelectionPolicy(
        mode: 'logo',
        typeHints: ['clearlogo', 'logo', 'wordmark'],
      ),
    );

    final detailPoster = seasonArtwork?.posterUrl ??
        _selectArtworkUrl(
          series,
          policy: const _ArtworkSelectionPolicy(
            mode: 'detail-poster',
            typeHints: ['poster', 'cover', 'keyart'],
            targetAspectRatio: 2 / 3,
            preferPortrait: true,
            preferNoText: false,
            strictNoText: false,
          ),
        ) ??
        _extractArtworkUrl(series, typeHints: const ['poster', 'cover', 'keyart']);

    final detailBackdrop = seasonArtwork?.bannerUrl ??
        _selectArtworkUrl(
          series,
          policy: const _ArtworkSelectionPolicy(
            mode: 'detail-backdrop',
            typeHints: ['banner', 'fanart', 'background'],
            targetAspectRatio: 16 / 9,
            preferLandscape: true,
            preferNoText: true,
            strictNoText: true,
          ),
        ) ??
        _selectArtworkUrl(
          series,
          policy: const _ArtworkSelectionPolicy(
            mode: 'detail-backdrop-fallback',
            typeHints: [],
            targetAspectRatio: 16 / 9,
            preferLandscape: true,
            preferNoText: true,
            strictNoText: true,
          ),
        );

    final carouselBackdrop = _selectArtworkUrl(
          series,
          policy: const _ArtworkSelectionPolicy(
            mode: 'carousel-backdrop',
            typeHints: ['banner', 'fanart', 'background'],
            targetAspectRatio: 16 / 9,
            preferLandscape: true,
            preferNoText: true,
            strictNoText: true,
          ),
        ) ??
        _selectArtworkUrl(
          series,
          policy: const _ArtworkSelectionPolicy(
            mode: 'carousel-poster-no-text',
            typeHints: ['poster', 'cover', 'keyart'],
            targetAspectRatio: 2 / 3,
            preferPortrait: true,
            preferNoText: true,
            strictNoText: true,
          ),
        ) ??
        detailBackdrop;

    _debugSurfaceResolution(
      malId: malId,
      tvdbId: tvdbId,
      logoUrl: logoUrl,
      detailPosterUrl: detailPoster,
      detailBackdropUrl: detailBackdrop,
      carouselBackdropUrl: carouselBackdrop,
    );

    return _SurfaceArtworkResult(
      logoUrl: logoUrl,
      detailPosterUrl: detailPoster,
      detailBackdropUrl: detailBackdrop,
      carouselBackdropUrl: carouselBackdrop,
    );
  }

  String? _selectArtworkUrl(
    Map<String, dynamic> series, {
    required _ArtworkSelectionPolicy policy,
  }) {
    final matches = _selectArtworkMatchesByPolicy(series, policy);
    if (matches.isEmpty) return null;

    final languagePreferred = _prioritizeEnglishCandidates(matches);
    if (languagePreferred.isEmpty) return null;

    final best = _pickBestArtworkByPolicy(languagePreferred, policy);
    final image = _extractImageFromArtwork(best);
    if (image == null || image.isEmpty) return null;

    _debugArtworkSelection(
      mode: policy.mode,
      hints: policy.typeHints,
      selected: best,
      image: image,
    );

    return image;
  }

  List<Map<String, dynamic>> _selectArtworkMatchesByPolicy(
    Map<String, dynamic> series,
    _ArtworkSelectionPolicy policy,
  ) {
    final artworks = _extractArtworkRecords(series);
    if (artworks.isEmpty) return const [];

    final normalizedHints = policy.typeHints.map((e) => e.toLowerCase()).toList();
    final selected = <Map<String, dynamic>>[];

    for (final artwork in artworks) {
      final image = _extractImageFromArtwork(artwork);
      if (image == null || image.isEmpty) continue;

      if (policy.strictNoText && _hasEmbeddedText(artwork)) {
        continue;
      }

      if (normalizedHints.isNotEmpty) {
        final typeTokens = _artworkTypeTokens(artwork);
        final hasMatch = normalizedHints.any(
          (hint) => typeTokens.any((token) => token.contains(hint)),
        );
        if (!hasMatch) continue;
      }

      selected.add(artwork);
    }

    return selected;
  }

  Map<String, dynamic> _pickBestArtworkByPolicy(
    List<Map<String, dynamic>> artworks,
    _ArtworkSelectionPolicy policy,
  ) {
    if (artworks.length <= 1) return artworks.first;

    final ranked = [...artworks];
    ranked.sort((a, b) {
      return _artworkRankScore(
        b,
        policy: policy,
      ).compareTo(
        _artworkRankScore(
          a,
          policy: policy,
        ),
      );
    });
    return ranked.first;
  }

  double _artworkRankScore(
    Map<String, dynamic> artwork, {
    required _ArtworkSelectionPolicy policy,
  }) {
    final apiScore = (artwork['score'] as num?)?.toDouble() ?? 0;
    var score = apiScore;

    final includesText = _hasEmbeddedText(artwork);
    if (policy.preferNoText) {
      score += includesText ? -80 : 80;
    }

    final language = artwork['language']?.toString().trim().toLowerCase();
    if (language == 'eng' || language == 'en') {
      score += 15;
    } else if (language == null || language.isEmpty) {
      score += 5;
    }

    final width = _toInt(artwork['width']) ?? _toInt(artwork['thumbnailWidth']);
    final height = _toInt(artwork['height']) ?? _toInt(artwork['thumbnailHeight']);
    if (width != null && height != null && width > 0 && height > 0) {
      final area = width * height;
      score += (area / 100000).clamp(0, 60).toDouble();

      final aspect = width / height;
      if (policy.targetAspectRatio != null) {
        final delta = (aspect - policy.targetAspectRatio!).abs();
        score += (20 - (delta * 40)).clamp(-20, 20).toDouble();
      }

      if (policy.preferLandscape) {
        score += width >= height ? 8 : -8;
      }
      if (policy.preferPortrait) {
        score += height > width ? 8 : -8;
      }
    }

    return score;
  }

  bool _hasEmbeddedText(Map<String, dynamic> artwork) {
    final value = artwork['includesText'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> _prioritizeEnglishCandidates(
    List<Map<String, dynamic>> candidates,
  ) {
    if (candidates.isEmpty) return const [];

    final english = <Map<String, dynamic>>[];
    final neutral = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];

    for (final candidate in candidates) {
      final language = candidate['language']?.toString().trim().toLowerCase();
      if (language == 'eng' || language == 'en') {
        english.add(candidate);
      } else if (language == null || language.isEmpty || language == 'null') {
        neutral.add(candidate);
      } else {
        other.add(candidate);
      }
    }

    if (english.isNotEmpty) return english;
    if (neutral.isNotEmpty) return neutral;
    return other;
  }

  String? _extractArtworkUrl(
    Map<String, dynamic> series, {
    required List<String> typeHints,
  }) {
    final matches = _selectArtworkMatchesByPolicy(
      series,
      _ArtworkSelectionPolicy(mode: 'soft', typeHints: typeHints),
    );
    if (matches.isNotEmpty) {
      final languagePreferred = _prioritizeEnglishCandidates(matches);
      if (languagePreferred.isEmpty) return null;

      final best = _pickBestArtworkByPolicy(
        languagePreferred,
        _ArtworkSelectionPolicy(mode: 'soft', typeHints: typeHints),
      );
      final image = _extractImageFromArtwork(best);
      if (image != null && image.isNotEmpty) {
        _debugArtworkSelection(
          mode: 'soft',
          hints: typeHints,
          selected: best,
          image: image,
        );
        return image;
      }
    }

    for (final key in ['image', 'image_url', 'banner', 'poster']) {
      final url = series[key] as String?;
      if (url != null && url.isNotEmpty) return url;
    }

    return null;
  }

  String? _extractArtworkUrlStrict(
    Map<String, dynamic> series, {
    required List<String> typeHints,
  }) {
    final matches = _selectArtworkMatchesByPolicy(
      series,
      _ArtworkSelectionPolicy(mode: 'strict', typeHints: typeHints),
    );
    if (matches.isEmpty) return null;

    final languagePreferred = _prioritizeEnglishCandidates(matches);
    if (languagePreferred.isEmpty) return null;

    final best = _pickBestArtworkByPolicy(
      languagePreferred,
      _ArtworkSelectionPolicy(mode: 'strict', typeHints: typeHints),
    );
    final image = _extractImageFromArtwork(best);
    if (image != null && image.isNotEmpty) {
      _debugArtworkSelection(
        mode: 'strict',
        hints: typeHints,
        selected: best,
        image: image,
      );
      return image;
    }

    return null;
  }

  Future<Map<int, String>> _getArtworkTypeMap() async {
    if (_artworkTypeById != null) return _artworkTypeById!;

    final cacheKey = 'tvdb_artwork_types';
    final cached = await _cache.getRaw(cacheKey);
    if (cached != null) {
      final map = <int, String>{};
      cached.forEach((key, value) {
        final id = int.tryParse(key.toString());
        final name = value?.toString().trim();
        if (id != null && name != null && name.isNotEmpty) {
          map[id] = name.toLowerCase();
        }
      });
      if (map.isNotEmpty) {
        _artworkTypeById = map;
        return map;
      }
    }

    final ready = await _ensureToken();
    if (!ready) return const {};

    try {
      final response = await _tvdbDio.get('/artwork/types');
      final data = response.data;
      if (data is! Map) return const {};

      final payload = data['data'];
      if (payload is! List) return const {};

      final map = <int, String>{};
      for (final item in payload) {
        if (item is! Map) continue;
        final normalized = item.cast<String, dynamic>();
        final id = (normalized['id'] as num?)?.toInt();
        if (id == null) continue;

        final parts = [
          normalized['name'],
          normalized['slug'],
          normalized['recordType'],
          normalized['imageFormat'],
        ].map((e) => e?.toString().trim().toLowerCase()).whereType<String>();
        final label = parts.where((e) => e.isNotEmpty).join(' ');
        if (label.isNotEmpty) {
          map[id] = label;
        }
      }

      if (map.isNotEmpty) {
        await _cache.set(cacheKey, map, ttl: CacheService.longCache);
        _artworkTypeById = map;
      }

      return map;
    } catch (_) {
      return const {};
    }
  }

  List<Map<String, dynamic>> _extractArtworkRecords(Map<String, dynamic> series) {
    final collected = <Map<String, dynamic>>[];
    final candidates = [
      series['artworks'],
      series['artwork'],
      (series['data'] is Map)
          ? (series['data'] as Map<String, dynamic>)['artworks']
          : null,
      (series['data'] is Map)
          ? (series['data'] as Map<String, dynamic>)['artwork']
          : null,
    ];

    for (final candidate in candidates) {
      if (candidate is! List) continue;
      for (final item in candidate) {
        if (item is! Map) continue;
        collected.add(item.cast<String, dynamic>());
      }
    }

    return collected;
  }

  List<String> _artworkTypeTokens(Map<String, dynamic> artwork) {
    final tokens = <String>[];

    final rawType = artwork['type'];
    if (rawType is String && rawType.trim().isNotEmpty) {
      tokens.add(rawType.trim().toLowerCase());
    }
    if (rawType is num) {
      final mapped = _artworkTypeById?[rawType.toInt()];
      if (mapped != null && mapped.isNotEmpty) {
        tokens.add(mapped);
      }
    }

    for (final key in ['typeName', 'name', 'slug', 'recordType']) {
      final value = artwork[key]?.toString().trim().toLowerCase();
      if (value != null && value.isNotEmpty) {
        tokens.add(value);
      }
    }

    return tokens;
  }

  String? _extractImageFromArtwork(Map<String, dynamic> artwork) {
    for (final key in ['image', 'thumbnail', 'url', 'image_url']) {
      final value = artwork[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  void _debugArtworkSelection({
    required String mode,
    required List<String> hints,
    required Map<String, dynamic> selected,
    required String image,
  }) {
    if (!_artworkDebug) return;

    final typeId = (selected['type'] as num?)?.toInt();
    final typeName = _artworkTypeTokens(selected).join(' | ');
    final score = selected['score'];
    final shortImage = image.length > 120 ? '${image.substring(0, 120)}…' : image;

    print(
      '[TVDB][Artwork][$mode] hints=${hints.join(',')} '
      'typeId=${typeId ?? 'n/a'} type="$typeName" score=${score ?? 'n/a'} '
      'url=$shortImage',
    );
  }

  void _debugSurfaceResolution({
    required int malId,
    required int tvdbId,
    required String? logoUrl,
    required String? detailPosterUrl,
    required String? detailBackdropUrl,
    required String? carouselBackdropUrl,
  }) {
    if (!_artworkDebug) return;

    print(
      '[TVDB][Surface] mal=$malId tvdb=$tvdbId '
      'logo=${logoUrl != null && logoUrl.isNotEmpty ? 'yes' : 'no'} '
      'detailPoster=${detailPosterUrl != null && detailPosterUrl.isNotEmpty ? 'yes' : 'no'} '
      'detailBackdrop=${detailBackdropUrl != null && detailBackdropUrl.isNotEmpty ? 'yes' : 'no'} '
      'carousel=${carouselBackdropUrl != null && carouselBackdropUrl.isNotEmpty ? 'yes' : 'no'}',
    );
  }

  String? _extractFirstArtworkField(
    Map<String, dynamic> series,
    List<String> fieldNames,
  ) {
    for (final key in fieldNames) {
      final value = series[key] as String?;
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

class TvdbMappingEntry {
  final int malId;
  final int tvdbId;
  final int tvdbSeason;
  final int start;
  final bool useMapping;

  const TvdbMappingEntry({
    required this.malId,
    required this.tvdbId,
    required this.tvdbSeason,
    required this.start,
    required this.useMapping,
  });

  Map<String, dynamic> toJson() => {
        'malId': malId,
        'tvdbId': tvdbId,
        'tvdbSeason': tvdbSeason,
        'start': start,
        'useMapping': useMapping,
      };

  factory TvdbMappingEntry.fromJson(Map<String, dynamic> json) {
    return TvdbMappingEntry(
      malId: (json['malId'] as num?)?.toInt() ?? 0,
      tvdbId: (json['tvdbId'] as num?)?.toInt() ?? 0,
      tvdbSeason: (json['tvdbSeason'] as num?)?.toInt() ?? 1,
      start: (json['start'] as num?)?.toInt() ?? 0,
      useMapping: json['useMapping'] as bool? ?? false,
    );
  }
}

class TvdbArtworkMetadata {
  final String? logoUrl;
  final String? posterUrl;
  final String? bannerUrl;
  final String? carouselBackdropUrl;

  const TvdbArtworkMetadata({
    this.logoUrl,
    this.posterUrl,
    this.bannerUrl,
    this.carouselBackdropUrl,
  });

  Map<String, dynamic> toJson() => {
        'logoUrl': logoUrl ?? '',
        'posterUrl': posterUrl ?? '',
        'bannerUrl': bannerUrl ?? '',
        'carouselBackdropUrl': carouselBackdropUrl ?? '',
      };

  factory TvdbArtworkMetadata.fromJson(Map<String, dynamic> json) {
    String? toNullableString(dynamic value) {
      final normalized = value?.toString().trim();
      if (normalized == null || normalized.isEmpty) return null;
      return normalized;
    }

    return TvdbArtworkMetadata(
      logoUrl: toNullableString(json['logoUrl']),
      posterUrl: toNullableString(json['posterUrl']),
      bannerUrl: toNullableString(json['bannerUrl']),
      carouselBackdropUrl: toNullableString(json['carouselBackdropUrl']),
    );
  }
}

class TvdbSimilarSeries {
  final int? tvdbId;
  final int? malId;
  final String? sourceType;
  final String title;
  final String? overview;
  final String? imageUrl;
  final double? score;
  final int? year;

  const TvdbSimilarSeries({
    required this.tvdbId,
    required this.malId,
    required this.sourceType,
    required this.title,
    required this.overview,
    required this.imageUrl,
    required this.score,
    required this.year,
  });

  Map<String, dynamic> toJson() => {
        'tvdbId': tvdbId,
        'malId': malId,
        'sourceType': sourceType ?? 'anime',
        'title': title,
        'overview': overview ?? '',
        'imageUrl': imageUrl ?? '',
        'score': score,
        'year': year,
      };

  factory TvdbSimilarSeries.fromJson(Map<String, dynamic> json) {
    final rawScore = json['score'];
    return TvdbSimilarSeries(
      tvdbId: (json['tvdbId'] as num?)?.toInt(),
      malId: (json['malId'] as num?)?.toInt(),
        sourceType: (json['sourceType']?.toString().trim().isEmpty ?? true)
          ? 'anime'
          : json['sourceType']?.toString().trim().toLowerCase(),
      title: json['title']?.toString() ?? '',
      overview: json['overview']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      score: rawScore is num ? rawScore.toDouble() : double.tryParse('${rawScore ?? ''}'),
      year: (json['year'] as num?)?.toInt(),
    );
  }
}

class _ArtworkSelectionPolicy {
  final String mode;
  final List<String> typeHints;
  final bool strictNoText;
  final bool preferNoText;
  final bool preferLandscape;
  final bool preferPortrait;
  final double? targetAspectRatio;

  const _ArtworkSelectionPolicy({
    required this.mode,
    required this.typeHints,
    this.strictNoText = false,
    this.preferNoText = false,
    this.preferLandscape = false,
    this.preferPortrait = false,
    this.targetAspectRatio,
  });
}

class _SurfaceArtworkResult {
  final String? logoUrl;
  final String? detailPosterUrl;
  final String? detailBackdropUrl;
  final String? carouselBackdropUrl;

  const _SurfaceArtworkResult({
    required this.logoUrl,
    required this.detailPosterUrl,
    required this.detailBackdropUrl,
    required this.carouselBackdropUrl,
  });
}

class _MalLookupProfile {
  final int malId;
  final List<String> titles;
  final int? year;

  const _MalLookupProfile({
    required this.malId,
    required this.titles,
    required this.year,
  });
}

class _TvdbSeriesCandidate {
  final int tvdbId;
  final String name;
  final int? year;

  const _TvdbSeriesCandidate({
    required this.tvdbId,
    required this.name,
    required this.year,
  });
}

class _EpisodeEnglishTranslation {
  final String? name;
  final String? overview;

  const _EpisodeEnglishTranslation({
    required this.name,
    required this.overview,
  });

  bool get hasContent =>
      (name != null && name!.trim().isNotEmpty) ||
      (overview != null && overview!.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'name': name ?? '',
        'overview': overview ?? '',
      };

  factory _EpisodeEnglishTranslation.fromJson(Map<String, dynamic> json) {
    String? toNullableString(dynamic value) {
      final normalized = value?.toString().trim();
      if (normalized == null || normalized.isEmpty) return null;
      return normalized;
    }

    return _EpisodeEnglishTranslation(
      name: toNullableString(json['name']),
      overview: toNullableString(json['overview']),
    );
  }
}
