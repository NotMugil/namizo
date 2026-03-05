import 'package:aimi_lib/aimi_lib.dart' as aimi;
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/models/media/stream_result.dart';

/// Anime streaming via aimi_lib providers (AnimePahe/AllAnime/Anizone).
class AimiAnimeService {
  static const List<_ProviderConfig> _providerOrder = [
    _ProviderConfig('AllAnime', _ProviderKind.allAnime),
    _ProviderConfig('AnimePahe', _ProviderKind.animePahe),
    _ProviderConfig('Anizone', _ProviderKind.anizone),
  ];

  static int get providerCount => _providerOrder.length;

  static String providerNameAt(int index) {
    if (index >= 0 && index < _providerOrder.length) {
      return _providerOrder[index].name;
    }
    return 'Unknown';
  }

  Future<StreamResult?> fetchAnimeStream({
    required SearchResult media,
    required int episode,
    String subDubPreference = 'sub',
    int? providerIndex,
  }) async {
    final queries = _buildQueryCandidates(media);
    if (queries.isEmpty) return null;

    final providers = _providerConfigsFor(providerIndex);
    for (final config in providers) {
      final provider = _createProvider(config.kind);
      try {
        for (final query in queries) {
          final results = await provider.search(query);
          if (results.isEmpty) continue;

          final best = _pickBestMatch(
            results,
            queryTitle: queries.first,
            targetEpisode: episode,
          );
          if (best == null) continue;

          final episodes = await best.getEpisodes();
          if (episodes.isEmpty) continue;

          final pickedEpisode = _pickEpisode(episodes, episode);
          if (pickedEpisode == null) continue;

          final sources = await pickedEpisode.getSources(
            options: {
              'mode': subDubPreference.toLowerCase() == 'dub' ? 'dub' : 'sub',
            },
          );

          final mapped = _mapSources(sources);
          if (mapped.isEmpty) continue;

          final bestSource = _pickBestSource(
            mapped,
            preferM3U8: config.kind == _ProviderKind.animePahe,
          );
          final headers =
              sources.firstWhere((s) => s.url == bestSource.url).headers ??
              const <String, String>{};

          return StreamResult(
            url: bestSource.url,
            quality: bestSource.quality,
            provider: config.name,
            isM3U8: bestSource.isM3U8,
            headers: headers,
            sources: mapped,
            availableQualities: mapped.map((s) => s.quality).toSet().toList(),
          );
        }
      } catch (_) {
        // Provider failed — try next provider.
      } finally {
        _closeProvider(provider);
      }
    }

    return null;
  }

  List<_ProviderConfig> _providerConfigsFor(int? providerIndex) {
    if (providerIndex == null) return _providerOrder;
    if (providerIndex < 0 || providerIndex >= _providerOrder.length) {
      return const [];
    }
    return [_providerOrder[providerIndex]];
  }

  List<StreamSource> _mapSources(List<aimi.StreamSource> raw) {
    final seen = <String>{};
    final mapped = <StreamSource>[];
    for (final source in raw) {
      final url = source.url.trim();
      final type = source.type.toLowerCase();
      final lowerUrl = url.toLowerCase();
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      mapped.add(
        StreamSource(
          url: url,
          quality: _normalizeQuality(source.quality),
          isM3U8:
              type.contains('hls') ||
              type.contains('m3u8') ||
              lowerUrl.contains('.m3u8') ||
              lowerUrl.contains('m3u8'),
          isDub: false,
        ),
      );
    }
    return mapped;
  }

  aimi.StreamProvider _createProvider(_ProviderKind kind) {
    switch (kind) {
      case _ProviderKind.animePahe:
        return aimi.AnimePahe();
      case _ProviderKind.allAnime:
        return aimi.AllAnime();
      case _ProviderKind.anizone:
        return aimi.Anizone();
    }
  }

  void _closeProvider(aimi.StreamProvider provider) {
    if (provider is aimi.AnimePahe) provider.close();
    if (provider is aimi.AllAnime) provider.close();
    if (provider is aimi.Anizone) provider.close();
  }

  List<String> _buildQueryCandidates(SearchResult media) {
    final set = <String>{};
    final values = [media.title, media.name];
    for (final raw in values) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty) continue;
      set.add(value);
      // Remove trailing "(YYYY)" for cleaner stream-site search.
      set.add(value.replaceAll(RegExp(r'\(\d{4}\)$'), '').trim());
    }
    return set.where((e) => e.isNotEmpty).toList();
  }

  aimi.StreamableAnime? _pickBestMatch(
    List<aimi.StreamableAnime> results, {
    required String queryTitle,
    required int targetEpisode,
  }) {
    if (results.isEmpty) return null;
    final normalizedQuery = _normalize(queryTitle);

    aimi.StreamableAnime? best;
    var bestScore = -1;

    for (final item in results) {
      final title = _normalize(item.title);
      var score = 0;

      if (title == normalizedQuery) score += 1000;
      if (title.startsWith(normalizedQuery)) score += 450;
      if (title.contains(normalizedQuery)) score += 300;

      for (final token in normalizedQuery.split(' ')) {
        if (token.isEmpty) continue;
        if (title.contains(token)) score += 60;
      }

      final available = item.availableEpisodes;
      if (available != null) {
        if (available >= targetEpisode) {
          score += 120;
        } else {
          score -= 300;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    return best;
  }

  aimi.Episode? _pickEpisode(List<aimi.Episode> episodes, int episodeNumber) {
    for (final episode in episodes) {
      if (episode.number.trim() == '$episodeNumber') return episode;
      final asDouble = double.tryParse(episode.number.trim());
      if (asDouble != null && asDouble == episodeNumber.toDouble()) {
        return episode;
      }
    }
    // Index fallback for providers where numbering is sparse strings.
    final idx = episodeNumber - 1;
    if (idx >= 0 && idx < episodes.length) return episodes[idx];
    return null;
  }

  StreamSource _pickBestSource(
    List<StreamSource> sources, {
    bool preferM3U8 = false,
  }) {
    final sorted = [...sources]
      ..sort((a, b) {
        var aScore = _qualityScore(a.quality);
        var bScore = _qualityScore(b.quality);
        if (preferM3U8) {
          if (a.isM3U8) aScore += 10000;
          if (b.isM3U8) bScore += 10000;
        }
        return bScore.compareTo(aScore);
      });
    return sorted.first;
  }

  int _qualityScore(String quality) {
    final normalized = _normalizeQuality(quality);
    if (normalized == 'auto') return 10;

    final numMatch = RegExp(r'(\d{3,4})p').firstMatch(normalized);
    if (numMatch != null) {
      return int.tryParse(numMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  String _normalizeQuality(String value) {
    final v = value.toLowerCase().trim();
    if (v.isEmpty || v == 'default' || v == 'auto') return 'auto';

    final pMatch = RegExp(r'(\d{3,4})p').firstMatch(v);
    if (pMatch != null) return '${pMatch.group(1)}p';

    final resMatch = RegExp(r'(\d{3,4})x(\d{3,4})').firstMatch(v);
    if (resMatch != null) return '${resMatch.group(2)}p';

    final rawNumber = RegExp(r'\b(\d{3,4})\b').firstMatch(v);
    if (rawNumber != null) return '${rawNumber.group(1)}p';

    return value;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

enum _ProviderKind { animePahe, allAnime, anizone }

class _ProviderConfig {
  final String name;
  final _ProviderKind kind;

  const _ProviderConfig(this.name, this.kind);
}
