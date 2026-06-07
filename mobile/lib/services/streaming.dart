import 'package:namizo/core/config.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/models/media/stream_result.dart';

/// Streaming service — direct provider logic removed pending new implementation.
/// Only embed/WebView providers remain.
class StreamingService {
  static final List<Map<String, String>> _embedProviders = [
    {'name': 'vidsrc.cc', 'url': 'https://vidsrc.cc/v2/embed'},
    {'name': 'vidsrc.to', 'url': 'https://vidsrc.to/embed'},
    {'name': 'vidlink', 'url': 'https://vidlink.pro'},
  ];

  StreamingService();

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
      final embedIdx = providerIndex;
      if (embedIdx >= _embedProviders.length) return null;

      final provider = _embedProviders[embedIdx];
      final String streamUrl;
      if (provider['name'] == 'vidsrc.cc') {
        streamUrl = '${provider['url']}/tv/${media.id}/$season/$episode?autoPlay=true';
      } else if (provider['name'] == 'vidlink') {
        streamUrl = '${provider['url']}/tv/${media.id}/$season/$episode?nextbutton=true';
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

  static int getTotalProviders({SearchResult? media}) => _embedProviders.length;

  static String getProviderName(int index, {SearchResult? media}) {
    if (index >= 0 && index < _embedProviders.length) {
      return _embedProviders[index]['name']!;
    }
    return 'Unknown';
  }

  static bool isDirectStream(int providerIndex, {SearchResult? media}) => false;
}
