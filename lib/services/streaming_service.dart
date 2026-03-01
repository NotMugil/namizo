import 'package:dio/dio.dart';
import 'package:nivio/models/search_result.dart';
import 'package:nivio/models/stream_result.dart';
import 'package:nivio/services/aimi_anime_service.dart';

/// Service for fetching anime streaming URLs.
/// Primary: AIMI direct sources.
/// Fallback: vidsrc.cc, vidsrc.to, vidlink.pro (embed/WebView).
class StreamingService {
  final AimiAnimeService _aimiAnimeService = AimiAnimeService();
  final Dio _probeDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  StreamingService();

  static final List<Map<String, String>> _embedProviders = [
    {'name': 'vidsrc.cc', 'url': 'https://vidsrc.cc/v2/embed'},
    {'name': 'vidsrc.to', 'url': 'https://vidsrc.to/embed'},
    {'name': 'vidlink', 'url': 'https://vidlink.pro'},
  ];

  Future<StreamResult?> fetchStreamUrl({
    required SearchResult media,
    int season = 1,
    int episode = 1,
    String? preferredQuality,
    int providerIndex = 0,
    bool autoSkipIntro = true,
    String subDubPreference = 'sub',
  }) async {
    try {
      if (providerIndex == 0) {
        final animeResult = await _aimiAnimeService.fetchAnimeStream(
          media: media,
          episode: episode,
          subDubPreference: subDubPreference,
        );

        if (animeResult != null) {
          final normalizedResult = StreamResult(
            url: animeResult.url,
            quality: animeResult.quality,
            provider: animeResult.provider,
            subtitles: animeResult.subtitles,
            availableQualities: animeResult.availableQualities,
            isM3U8: animeResult.isM3U8,
            headers: _buildDirectHeaders(animeResult.headers),
            sources: animeResult.sources,
          );

          await _probeDirectHls(normalizedResult);
          return normalizedResult;
        }

        return null;
      }

      final embedIdx = providerIndex - 1;
      if (embedIdx >= _embedProviders.length) {
        return null;
      }

      final provider = _embedProviders[embedIdx];
      final String streamUrl;
      if (provider['name'] == 'vidsrc.cc') {
        streamUrl =
            '${provider['url']}/tv/${media.id}/$season/$episode?autoPlay=true';
      } else if (provider['name'] == 'vidlink') {
        streamUrl =
            '${provider['url']}/tv/${media.id}/$season/$episode?nextbutton=true';
      } else {
        streamUrl = '${provider['url']}/tv/${media.id}/$season/$episode';
      }

      return StreamResult(
        url: streamUrl,
        quality: preferredQuality ?? 'auto',
        provider: provider['name']!,
      );
    } catch (_) {
      return null;
    }
  }

  static int get totalProviders => 1 + _embedProviders.length;

  static String getProviderName(int index) {
    if (index == 0) return 'Direct';
    final embedIdx = index - 1;
    if (embedIdx < _embedProviders.length) {
      return _embedProviders[embedIdx]['name']!;
    }
    return 'Unknown';
  }

  static bool isDirectStream(int providerIndex) {
    return providerIndex == 0;
  }

  Future<bool> _probeDirectHls(StreamResult result) async {
    if (!result.isM3U8 || result.url.trim().isEmpty) {
      return true;
    }

    final requestHeaders = _buildDirectHeaders(result.headers);

    try {
      final response = await _probeDio.get<String>(
        result.url,
        options: Options(
          headers: requestHeaders,
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          (response.data?.contains('#EXTM3U') ?? false);
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _buildDirectHeaders(Map<String, String> incoming) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      ...incoming,
    };

    final refererEntry = headers.entries.where(
      (e) => e.key.toLowerCase() == 'referer',
    );
    final hasOrigin = headers.keys.any((k) => k.toLowerCase() == 'origin');
    if (refererEntry.isNotEmpty && !hasOrigin) {
      final referer = refererEntry.first.value;
      final refUri = Uri.tryParse(referer);
      if (refUri != null &&
          refUri.scheme.isNotEmpty &&
          refUri.host.isNotEmpty) {
        headers['Origin'] = '${refUri.scheme}://${refUri.host}';
      }
    }

    headers.putIfAbsent('Accept', () => '*/*');
    return headers;
  }
}
