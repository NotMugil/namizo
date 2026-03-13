import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import '../models/anime_details.dart';
import '../models/episode.dart';
import '../models/stream_source.dart';
import '../models/streamable_anime.dart';
import 'stream_provider.dart';

/// A [StreamProvider] implementation for Anidap.
///
/// Supports optional constructor hooks (`nowUtc`, `tokenDecoder`) to make
/// source decoding deterministic in unit tests.
class Anidap implements StreamProvider {
  @override
  String get name => 'Anidap';

  static const String _baseUrl = 'https://anidap.se';
  static const String _defaultHost = 'yuki';
  static const String _defaultMode = 'sub';
  static const List<String> _fallbackHosts = [
    'nuri',
    'koto',
    'pahe',
    'ozzy',
    'dih',
    'mizu',
    'kami',
    'yuki',
  ];

  static const Map<String, String> _originByHost = {
    'yuki': 'https://vidwish.live',
    'kami': 'https://krussdomi.com',
    'ozzy': 'https://megaup.live',
  };

  static const Map<String, String> _baseHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  final http.Client _client;
  final DateTime Function() _nowUtc;
  final Future<String> Function(String token)? _tokenDecoder;
  late final _AnidapDecoder _decoder;

  bool _sessionPrimed = false;

  Anidap({
    http.Client? client,
    DateTime Function()? nowUtc,
    Future<String> Function(String token)? tokenDecoder,
  }) : _client = client ?? http.Client(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _tokenDecoder = tokenDecoder {
    _decoder = _AnidapDecoder(nowUtc: _nowUtc);
  }

  @override
  Future<List<StreamableAnime>> search(dynamic query) async {
    final searchQuery = _resolveQuery(query);
    await _primeSession();

    final uri = Uri.parse(
      '$_baseUrl/api/anime/search',
    ).replace(queryParameters: {'q': searchQuery});

    try {
      final response = await _getJson(
        uri,
        headers: {
          'Referer':
              '$_baseUrl/search?q=${Uri.encodeQueryComponent(searchQuery)}',
        },
      );

      final data = response['data'];
      final results = (data is Map ? data['results'] : null) as List?;
      if (results == null) return [];

      return results.map((e) {
        final item = e is Map ? e : const {};
        final titleData = item['title'];
        final title = _pickTitle(titleData);
        final currentEps = _toInt(item['currentEpisodeCount']);
        final totalEps = _toInt(item['totalEpisodes']);
        return StreamableAnime(
          id: (item['id'] ?? '').toString(),
          title: title.isEmpty ? 'Unknown' : title,
          availableEpisodes: currentEps ?? totalEps,
          stream: this,
        );
      }).toList();
    } catch (e) {
      throw Exception('Error searching anime: $e');
    }
  }

  @override
  Future<List<Episode>> getEpisodes(StreamableAnime anime) async {
    await _primeSession();
    final uri = Uri.parse(
      '$_baseUrl/api/anime/${anime.id}/episodes',
    ).replace(queryParameters: {'refresh': 'false'});

    try {
      final response = await _getJson(
        uri,
        headers: {
          'Referer': _watchReferer(anime.id, '1', _defaultHost, _defaultMode),
        },
      );

      final data = response['data'] as List?;
      if (data == null) return [];

      final episodes = data.map((e) {
        final item = e is Map ? e : const {};
        return Episode(
          animeId: anime.id,
          number: (item['number'] ?? '').toString(),
          stream: this,
        );
      }).toList();

      episodes.sort((a, b) {
        final aNum = double.tryParse(a.number) ?? 0;
        final bNum = double.tryParse(b.number) ?? 0;
        return aNum.compareTo(bNum);
      });
      return episodes;
    } catch (e) {
      throw Exception('Error getting episodes: $e');
    }
  }

  @override
  Future<List<StreamSource>> getSources(
    Episode episode, {
    Map<String, dynamic>? options,
  }) async {
    await _primeSession();

    final mode = (options?['mode'] ?? _defaultMode).toString();
    final preferredHost = (options?['host'] ?? _defaultHost).toString();
    final ep = episode.number;
    final animeId = episode.animeId;
    final hostsToTry = _buildHostOrder(preferredHost);

    List<StreamSource> bestEffort = [];
    for (final host in hostsToTry) {
      final sources = await _getSourcesForHost(animeId, ep, mode, host);
      if (sources.isEmpty) continue;

      final playable = sources
          .where((s) => _isLikelyPlayableUrl(s.url))
          .toList();
      if (playable.isNotEmpty) return playable;

      if (bestEffort.isEmpty) {
        // Keep non-playable result as a last resort, but continue host fallback.
        bestEffort = sources;
      }
    }

    return bestEffort;
  }

  Future<List<StreamSource>> _getSourcesForHost(
    String animeId,
    String ep,
    String mode,
    String host,
  ) async {
    final referer = _watchReferer(animeId, ep, host, mode);
    final uri = Uri.parse('$_baseUrl/api/anime/sources').replace(
      queryParameters: {'id': animeId, 'ep': ep, 'host': host, 'type': mode},
    );

    try {
      final response = await _getJson(uri, headers: {'Referer': referer});
      final data = response['data'];
      final parsed = await _parseSourcePayload(data, host, referer);
      if (parsed.isNotEmpty) return parsed;
      return _fallbackWatchSources(animeId, ep, host, mode);
    } catch (_) {
      return _fallbackWatchSources(animeId, ep, host, mode);
    }
  }

  Future<List<StreamSource>> _parseSourcePayload(
    dynamic payload,
    String host,
    String referer,
  ) async {
    if (payload == null) return [];

    if (payload is String && payload.startsWith('http')) {
      return [
        _buildSource(url: _applyHostOrigin(payload, host), referer: referer),
      ];
    }

    dynamic decodedPayload = payload;
    if (payload is String) {
      final decodedString =
          await (_tokenDecoder?.call(payload) ?? _decoder.decode(payload));
      if (decodedString.startsWith('http')) {
        return [
          _buildSource(
            url: _applyHostOrigin(decodedString, host),
            referer: referer,
          ),
        ];
      }
      decodedPayload = _tryJsonDecode(decodedString);
    }

    final sources = _extractUrls(decodedPayload);
    return sources
        .map(
          (e) => _buildSource(
            url: _applyHostOrigin(e.url, host),
            quality: e.quality,
            type: e.type,
            referer: referer,
          ),
        )
        .toList();
  }

  Future<List<StreamSource>> _fallbackWatchSources(
    String animeId,
    String ep,
    String host,
    String mode,
  ) async {
    try {
      final referer = _watchReferer(animeId, ep, host, mode);
      final response = await _get(
        Uri.parse(referer),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
        requireOk: true,
      );

      final body = response.body;
      final urls = <String>{};

      for (final match in RegExp(
        'https?://[^"\\\'\\s]+\\.m3u8[^"\\\'\\s]*',
      ).allMatches(body)) {
        final url = match.group(0);
        if (url != null) urls.add(url);
      }

      for (final match in RegExp(r'src="(https?://[^"]+)"').allMatches(body)) {
        final url = match.group(1);
        if (url == null) continue;
        if (url.contains('.m3u8') || url.contains('/storage/')) {
          urls.add(url);
        }
      }

      return urls
          .map(
            (url) => _buildSource(
              url: _applyHostOrigin(url, host),
              referer: referer,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  StreamSource _buildSource({
    required String url,
    String? quality,
    String? type,
    required String referer,
  }) {
    return StreamSource(
      url: url,
      quality: quality ?? 'auto',
      type: type ?? _inferType(url),
      headers: {'Referer': referer, 'User-Agent': _baseHeaders['User-Agent']!},
    );
  }

  String _applyHostOrigin(String url, String host) {
    final origin = _originByHost[host];
    if (origin == null || url.contains('origin=')) return url;
    return url.contains('?') ? '$url&origin=$origin' : '$url?origin=$origin';
  }

  List<_SourceCandidate> _extractUrls(dynamic payload) {
    final results = <_SourceCandidate>[];
    final seen = <String>{};

    void addCandidate(String? url, {String? quality, String? type}) {
      if (url == null || url.isEmpty || !seen.add(url)) return;
      results.add(_SourceCandidate(url: url, quality: quality, type: type));
    }

    if (payload is Map) {
      final sources = payload['sources'];
      if (sources is List) {
        for (final item in sources) {
          if (item is Map) {
            addCandidate(
              item['url']?.toString(),
              quality: item['quality']?.toString() ?? item['label']?.toString(),
              type: item['type']?.toString(),
            );
          }
        }
      }

      addCandidate(payload['url']?.toString());
      addCandidate(payload['source']?.toString());
    } else if (payload is List) {
      for (final item in payload) {
        if (item is Map) {
          addCandidate(
            item['url']?.toString(),
            quality: item['quality']?.toString() ?? item['label']?.toString(),
            type: item['type']?.toString(),
          );
        } else if (item is String) {
          addCandidate(item);
        }
      }
    }

    return results;
  }

  dynamic _tryJsonDecode(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  String _inferType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp4')) return 'mp4';
    if (lower.contains('.m3u8')) return 'hls';
    return 'hls';
  }

  List<String> _buildHostOrder(String preferredHost) {
    final order = <String>[preferredHost];
    for (final host in _fallbackHosts) {
      if (!order.contains(host)) order.add(host);
    }
    return order;
  }

  bool _isLikelyPlayableUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.mpd')) {
      return true;
    }
    if (lower.contains('/storage/')) return true;
    // CORS proxy /media URLs are often intermediate and may fail with HTTP 400.
    if (lower.contains('cors.anidap.se/media/')) return false;
    return false;
  }

  String _watchReferer(String animeId, String ep, String host, String mode) {
    final params = {'id': animeId, 'ep': ep, 'provider': host, 'type': mode};
    return Uri.parse(
      '$_baseUrl/watch',
    ).replace(queryParameters: params).toString();
  }

  String _resolveQuery(dynamic query) {
    if (query is AnimeDetails) return query.title;
    if (query is String) return query;
    throw ArgumentError('Query must be a String or AnimeDetails object');
  }

  String _pickTitle(dynamic titleData) {
    if (titleData is String) return titleData;
    if (titleData is! Map) return '';
    final candidates = [
      titleData['userPreferred'],
      titleData['english'],
      titleData['romaji'],
      titleData['native'],
    ];
    for (final item in candidates) {
      if (item is String && item.isNotEmpty) return item;
    }
    return '';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _primeSession() async {
    if (_sessionPrimed) return;
    _sessionPrimed = true;
    try {
      await _get(Uri.parse('$_baseUrl/home'), requireOk: false);
    } catch (_) {
      // Best effort only.
    }
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final response = await _get(uri, headers: headers, requireOk: true);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected JSON shape from Anidap');
  }

  Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
    required bool requireOk,
  }) async {
    final response = await _client
        .get(uri, headers: {..._baseHeaders, ...?headers})
        .timeout(const Duration(seconds: 30));

    if (requireOk && response.statusCode != 200) {
      throw Exception(
        'Request failed with status ${response.statusCode} for $uri',
      );
    }
    return response;
  }

  void close() {
    _client.close();
  }
}

class _SourceCandidate {
  final String url;
  final String? quality;
  final String? type;

  _SourceCandidate({required this.url, this.quality, this.type});
}

class _AnidapDecoder {
  static const int _periodMs = ((6 * 6 * 6) + 47) * 60 * 1000;
  static const List<int> _be = [
    13,
    27,
    7,
    19,
    31,
    11,
    23,
    37,
    41,
    43,
    47,
    53,
    59,
    61,
    67,
    71,
    73,
    79,
    83,
    89,
    97,
    101,
    103,
    107,
    109,
    113,
    127,
    131,
    137,
    139,
    149,
    151,
  ];

  final DateTime Function() _nowUtc;
  final AesGcm _aes = AesGcm.with256bits();
  _DerivedKeys? _cached;

  late final Uint8List _vt = Uint8List.fromList(
    List<int>.generate(
      32,
      (t) => ((t * 17 + 53) ^ (t * 23 + 79) ^ (t * 31 + 124)) & 0xff,
    ),
  );

  _AnidapDecoder({required DateTime Function() nowUtc}) : _nowUtc = nowUtc;

  Future<String> decode(String token) async {
    try {
      final payload = _decodeBase64Url(token);
      if (payload.length < 28) {
        return latin1.decode(payload, allowInvalid: true);
      }

      final now = _nowUtc();
      final bucket = now.millisecondsSinceEpoch ~/ _periodMs;

      for (final candidate in [bucket, bucket - 1]) {
        try {
          final keys = await _keysForBucket(candidate, now);
          final plaintext = await _decrypt(payload, keys.aesKey);
          final unxored = _xor(Uint8List.fromList(plaintext), keys.xorKey);
          return utf8.decode(unxored, allowMalformed: true);
        } catch (_) {
          // Try fallback bucket.
        }
      }

      return latin1.decode(payload, allowInvalid: true);
    } catch (_) {
      return token;
    }
  }

  Future<List<int>> _decrypt(Uint8List payload, SecretKey key) async {
    final nonce = payload.sublist(0, 12);
    final body = payload.sublist(12);
    if (body.length < 16) {
      throw Exception('Invalid encrypted payload');
    }

    final cipherText = body.sublist(0, body.length - 16);
    final mac = Mac(body.sublist(body.length - 16));
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    return _aes.decrypt(box, secretKey: key);
  }

  Future<_DerivedKeys> _keysForBucket(int bucket, DateTime now) async {
    final cached = _cached;
    if (cached != null &&
        cached.bucket == bucket &&
        now.isBefore(cached.expiresAt)) {
      return cached;
    }

    final derived = await _derive(bucket);
    _cached = derived;
    return derived;
  }

  Future<_DerivedKeys> _derive(int bucket) async {
    final t = Uint8List(128);
    for (var i = 0; i < 128; i++) {
      final u = _be[i % _be.length];
      t[i] = _u8(_xt(i) ^ _u8(bucket + i * u) ^ _u8(i ^ u));
    }

    final n = Uint8List(64);
    final r = Uint8List(32);
    final a = Uint8List(16);

    for (var i = 0; i < 64; i++) {
      final u = t[i];
      final m = t[i + 64];
      final d = _ie(u, m, _u8(bucket >>> (i % 16)));
      n[i] = _u8(u ^ d);
    }

    for (var i = 0; i < 32; i++) {
      final u = n[i];
      final m = n[i + 32];
      final d = _be[(i * 3 + 7) % _be.length];
      r[i] = _u8(u ^ m ^ _u8(u + m + d));
    }

    for (var i = 0; i < 16; i++) {
      final u = r[i];
      final m = r[i + 16];
      final d = _u8((((u << 3) | (u >>> 5)) ^ ((m << 5) | (m >>> 3))));
      a[i] = _u8(d ^ _u8(bucket >>> (i * 2)));
    }

    final c = Uint8List(48);
    for (var i = 0; i < 48; i++) {
      final u = (i * 7 + 11) % 32;
      final m = (i * 13 + 17) % 32;
      final d = (i * 19 + 23) % 32;
      final p = _ie(r[u], r[m], r[d]);
      c[i] = _u8(p ^ _u8(bucket >>> (i % 24)) ^ _xt(i * 3));
    }

    final l = Uint8List(32);
    for (var i = 0; i < 3; i++) {
      for (var u = 0; u < 32; u++) {
        final m = i == 0 ? c[u] : l[u];
        final d = c[(u * 5 + 7) % 48];
        final p = c[(u * 11 + 13) % 48];
        final v = _ie(m, d, p);
        l[u] = _u8(v ^ c[(u + i * 16) % 48]);
      }
    }

    final key = SecretKey(Uint8List.fromList(l));
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (bucket + 1) * _periodMs,
      isUtc: true,
    );
    return _DerivedKeys(
      bucket: bucket,
      aesKey: key,
      xorKey: a,
      expiresAt: expiresAt,
    );
  }

  Uint8List _xor(Uint8List input, Uint8List key) {
    final out = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      final a = i % key.length;
      final c = key[a];
      final l = _u8((c << (i % 8)) | (c >>> (8 - (i % 8))));
      final j = _u8(i * 7 + 13);
      out[i] = _u8(input[i] ^ l ^ j ^ key[(a + 1) % key.length]);
    }
    return out;
  }

  int _xt(int index) {
    return _u8(
      _vt[index % _vt.length] ^
          _vt[(index * 7 + 11) % _vt.length] ^
          _vt[(index * 13 + 17) % _vt.length],
    );
  }

  int _ie(int e, int t, int n) {
    return _u8(((e ^ t) << 1) ^ ((t ^ n) >> 1) ^ (e + t + n));
  }

  int _u8(int value) => value & 0xff;

  Uint8List _decodeBase64Url(String value) {
    var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return Uint8List.fromList(base64.decode(normalized));
  }
}

class _DerivedKeys {
  final int bucket;
  final SecretKey aesKey;
  final Uint8List xorKey;
  final DateTime expiresAt;

  _DerivedKeys({
    required this.bucket,
    required this.aesKey,
    required this.xorKey,
    required this.expiresAt,
  });
}
