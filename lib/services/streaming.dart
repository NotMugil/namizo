import 'package:dio/dio.dart';
import 'package:namizo/core/config.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/models/media/stream_result.dart';
import 'package:namizo/services/aimi.dart';

/// Service for fetching anime streaming URLs.
/// Primary: AIMI direct sources.
/// Fallback: vidsrc.cc, vidsrc.to, vidlink.pro (embed/WebView).
class StreamingService {
  final AimiAnimeService _aimiAnimeService = AimiAnimeService();
  final Dio _probeDio = Dio(
    BaseOptions(
      connectTimeout: shortTimeout,
      receiveTimeout: shortTimeout,
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
      if (_isAnimeMedia(media)) {
        if (providerIndex < 0 || providerIndex >= AimiAnimeService.providerCount) {
          return null;
        }

        final animeResult = await _aimiAnimeService.fetchAnimeStream(
          media: media,
          episode: episode,
          subDubPreference: subDubPreference,
          providerIndex: providerIndex,
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

      final embedIdx = providerIndex;
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

  static int getTotalProviders({SearchResult? media}) {
    if (_isAnimeMedia(media)) {
      return AimiAnimeService.providerCount;
    }
    return _embedProviders.length;
  }

  static String getProviderName(int index, {SearchResult? media}) {
    if (_isAnimeMedia(media)) {
      return AimiAnimeService.providerNameAt(index);
    }

    if (index >= 0 && index < _embedProviders.length) {
      return _embedProviders[index]['name']!;
    }
    return 'Unknown';
  }

  static bool isDirectStream(int providerIndex, {SearchResult? media}) {
    return _isAnimeMedia(media) &&
        providerIndex >= 0 &&
        providerIndex < AimiAnimeService.providerCount;
  }

  static bool _isAnimeMedia(SearchResult? media) {
    if (media == null) return true;
    if (media.mediaType != 'tv') return false;

    final language = (media.originalLanguage ?? '').toLowerCase();
    return language == 'ja';
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
      'User-Agent': AppConfigurations.mobileChromeUserAgent,
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
