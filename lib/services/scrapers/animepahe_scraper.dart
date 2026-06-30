import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:namizo/models/media/stream_result.dart';
import 'package:namizo/services/cloudflare_bypass_service.dart';

void _log(String msg) {
  if (kDebugMode) {
    debugPrint('🎌 AnimepaheScraper: $msg');
  }
}

final animepaheScraperProvider = Provider<AnimepaheScraperService>((ref) {
  return AnimepaheScraperService(ref.read(cloudflareBypassProvider));
});

class AnimepaheScraperService {
  static final AnimepaheScraperService instance = AnimepaheScraperService(CloudflareBypassService.instance);

  final CloudflareBypassService _bypassService;
  
  AnimepaheScraperService(this._bypassService);

  /// Scrapes direct native .m3u8 or Kwik link from Animepahe
  Future<StreamResult?> fetchStreamUrl(
    String title,
    int season,
    int episode, {
    String subDub = 'sub',
    void Function(String)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('Warming up Animepahe bypass...');
      await _bypassService.waitForBypass();
      
      String? animeSession;
      int? absoluteEpisodeNumber;

      String queryTitle = season > 1 ? '$title Season $season' : title;

      // --- 1. MAPPING PHASE (Prioritized to resolve absolute episode number & exact session) ---
      try {
        onStatusUpdate?.call('Mapping: Querying AniList for "$queryTitle"...');
        
        final aniListReq = await http.post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': 'query { Media(search: "$queryTitle", type: ANIME, sort: POPULARITY_DESC) { id idMal title { romaji english } } }'
          }),
        ).timeout(const Duration(seconds: 5));

        if (aniListReq.statusCode == 200) {
          final aniData = jsonDecode(aniListReq.body);
          final media = aniData['data']?['Media'];
          if (media != null) {
            final int? idMal = media['idMal'];
            final int? idAni = media['id'];
            
            if (idMal != null) {
              onStatusUpdate?.call('Mapping: Resolving Session via MAL-Sync...');
              final malReq = await http.get(
                Uri.parse('https://api.malsync.moe/mal/anime/$idMal')
              ).timeout(const Duration(seconds: 5));

              if (malReq.statusCode == 200) {
                final malData = jsonDecode(malReq.body);
                final paheData = malData['Sites']?['animepahe'];
                if (paheData != null && paheData.isNotEmpty) {
                  animeSession = paheData.values.first['identifier'] as String?;
                  
                  if (animeSession != null && int.tryParse(animeSession) != null) {
                    onStatusUpdate?.call('Mapping: Resolving legacy Animepahe ID...');
                    final finalUrl = await _bypassService.getFinalUrlViaWebView('https://animepahe.pw/a/$animeSession');
                    if (finalUrl != null && finalUrl.contains('/anime/')) {
                      animeSession = finalUrl.split('/anime/').last;
                      _log('Resolved legacy ID to UUID session: $animeSession');
                    } else {
                      animeSession = null;
                    }
                  } else {
                    _log('Successfully mapped to session $animeSession via MAL-Sync.');
                  }
                }
              }
            }

            if (idAni != null) {
              onStatusUpdate?.call('Mapping: Resolving Episode via AniZip...');
              final zipReq = await http.get(
                Uri.parse('https://api.ani.zip/mappings?anilist_id=$idAni')
              ).timeout(const Duration(seconds: 5));

              if (zipReq.statusCode == 200) {
                final zipData = jsonDecode(zipReq.body);
                final episodesMap = zipData['episodes'] as Map<String, dynamic>?;
                if (episodesMap != null) {
                  for (var ep in episodesMap.values) {
                    if (ep is Map) {
                      final s = ep['seasonNumber'];
                      final e = ep['episodeNumber'];
                      if (s == season && e == episode) {
                        absoluteEpisodeNumber = ep['absoluteEpisodeNumber'] as int?;
                        _log('Resolved absolute episode number $absoluteEpisodeNumber via AniZip.');
                        break;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        _log('Mapping failed. Error: $e');
      }

      // --- 2. SEARCH PHASE (Fallback if Mapping yields no session) ---
      String? searchBody;
      if (animeSession == null) {
        onStatusUpdate?.call('Searching Animepahe for exact title match...');
        _log('Searching for "$title"');
        final searchUrl = 'https://animepahe.pw/api?m=search&q=${Uri.encodeComponent(title)}';
        searchBody = await _bypassService.fetchViaWebView(searchUrl);
        
        if (searchBody != null) {
          try {
            final searchJson = jsonDecode(searchBody);
            final data = searchJson['data'] as List?;
            if (data != null && data.isNotEmpty) {
              Map<String, dynamic>? bestMatch;
              
              for (var item in data) {
                final itemTitle = (item['title'] as String).toLowerCase();
                final itemType = (item['type'] as String?)?.toUpperCase() ?? '';
                if (itemTitle == queryTitle.toLowerCase() && itemType == 'TV') {
                  bestMatch = item as Map<String, dynamic>;
                  break;
                }
              }

              if (bestMatch == null) {
                for (var item in data) {
                  final itemTitle = (item['title'] as String).toLowerCase();
                  final itemType = (item['type'] as String?)?.toUpperCase() ?? '';
                  if (itemTitle == title.toLowerCase() && itemType == 'TV') {
                    bestMatch = item as Map<String, dynamic>;
                    break;
                  }
                }
              }

              if (bestMatch == null) {
                for (var item in data) {
                  final itemTitle = (item['title'] as String).toLowerCase();
                  if (itemTitle == queryTitle.toLowerCase()) {
                    bestMatch = item as Map<String, dynamic>;
                    break;
                  }
                }
              }

              if (bestMatch == null) {
                for (var item in data) {
                  final itemTitle = (item['title'] as String).toLowerCase();
                  if (itemTitle == title.toLowerCase()) {
                    bestMatch = item as Map<String, dynamic>;
                    break;
                  }
                }
              }
              
              if (bestMatch != null) {
                animeSession = bestMatch['session'] as String;
                _log('Found title match in Search Phase: $animeSession');
              }
            }
          } catch (e) {
            _log('Search Phase failed: $e');
          }
        }
      }

      // --- 3. FINAL SEARCH FALLBACK (If everything else failed, just take the first search result) ---
      if (animeSession == null && searchBody != null) {
        try {
          final searchJson = jsonDecode(searchBody);
          final data = searchJson['data'] as List?;
          if (data != null && data.isNotEmpty) {
            animeSession = data[0]['session'] as String;
            _log('Fallback to first search result: $animeSession');
          }
        } catch (_) {}
      }
      
      // --- 3. FETCH EPISODES PHASE ---
      onStatusUpdate?.call('Fetching episodes list from Animepahe...');
      _log('Fetching episode list for session $animeSession');
      String? episodeSession;
      
      Future<String?> findEpisodeInSession(String session) async {
        int page = 1;
        while (page <= 10) {
          final releaseUrl = 'https://animepahe.pw/api?m=release&id=$session&sort=episode_asc&page=$page';
          final releaseBody = await _bypassService.fetchViaWebView(releaseUrl);
          if (releaseBody == null) return null;
          
          try {
            final releaseJson = jsonDecode(releaseBody);
            final releaseData = releaseJson['data'] as List?;
            if (releaseData == null || releaseData.isEmpty) return null;
            
            for (var ep in releaseData) {
              final epNum = ep['episode'];
              if (epNum == episode || epNum == absoluteEpisodeNumber || epNum == '$episode' || epNum == '$absoluteEpisodeNumber') {
                return ep['session'] as String;
              }
            }
            if (releaseJson['last_page'] == page) return null;
          } catch(e) {
            return null;
          }
          page++;
        }
        return null;
      }

      if (animeSession != null) {
         episodeSession = await findEpisodeInSession(animeSession);
      }
      
      // AGGRESSIVE FALLBACK: IF EPISODE NOT IN PRIMARY SESSION
      if (episodeSession == null) {
        onStatusUpdate?.call('Episode not found in primary session. Hunting across all seasons...');
        
        final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        _log('Episode not found in $animeSession. Hunting across all related seasons using cleaned title: "$cleanTitle"');
        
        final searchUrl = 'https://animepahe.pw/api?m=search&q=${Uri.encodeComponent(cleanTitle)}';
        final searchBody = await _bypassService.fetchViaWebView(searchUrl);
        
        if (searchBody != null) {
          try {
            final searchJson = jsonDecode(searchBody);
            final data = searchJson['data'] as List?;
            if (data != null && data.isNotEmpty) {
              final firstWord = title.split(' ').firstWhere((w) => w.length > 2, orElse: () => title).toLowerCase();
              final relevantCandidates = data.where((item) {
                final itemTitle = (item['title'] as String).toLowerCase();
                return itemTitle.contains(firstWord);
              }).toList();
              
              for (int i = 0; i < relevantCandidates.length && i < 15; i++) {
                final candidateSession = relevantCandidates[i]['session'] as String;
                if (candidateSession == animeSession) continue;
                
                onStatusUpdate?.call('Hunting in related season ${i+1}...');
                _log('Checking candidate session $candidateSession (${relevantCandidates[i]['title']})');
                final foundEpSession = await findEpisodeInSession(candidateSession);
                if (foundEpSession != null) {
                  animeSession = candidateSession;
                  episodeSession = foundEpSession;
                  _log('FOUND episode in candidate session $candidateSession');
                  break;
                }
              }
            }
          } catch(e) {
            _log('Aggressive hunt search parse failed: $e');
          }
        }
      }
      
      if (episodeSession == null) {
        _log('Could not find episode $episode (or abs: $absoluteEpisodeNumber) anywhere.');
        return null;
      }
      
      // --- 4. EXTRACT KWIK LINKS ---
      onStatusUpdate?.call('Extracting stream links from Animepahe...');
      _log('Fetching links for episode session $episodeSession');
      
      final playUrl = 'https://animepahe.pw/play/$animeSession/$episodeSession';
      final playHtml = await _bypassService.fetchViaWebView(playUrl);
      
      List<StreamSource> sources = [];
      List<String> qualities = [];
      
      if (playHtml != null && playHtml.contains('kwik')) {
        _log('Extracting links from Play HTML...');
        final tagRegex = RegExp(r'<[^>]+data-src="(https://kwik\.cx/e/[^"]+)"[^>]*>');
        final matches = tagRegex.allMatches(playHtml);
        
        List<Map<String, String>> extractedLinks = [];
        for (var match in matches) {
          final tagHtml = match.group(0)!;
          final src = match.group(1)!;
          
          final audioMatch = RegExp(r'data-audio="([^"]+)"').firstMatch(tagHtml);
          final resMatch = RegExp(r'data-resolution="([^"]+)"').firstMatch(tagHtml);
          
          final audio = audioMatch?.group(1) ?? 'jpn';
          final resolution = resMatch?.group(1) ?? '720';
          
          extractedLinks.add({
            'src': src,
            'audio': audio,
            'resolution': resolution,
          });
          
          final isDub = audio != 'jpn';
          sources.add(StreamSource(
            url: src,
            quality: '${resolution}p',
            isM3U8: false,
            isDub: isDub,
          ));
          
          final q = '${resolution}p';
          if (!qualities.contains(q)) qualities.add(q);
        }
        
        if (extractedLinks.isNotEmpty) {
          _log('Successfully extracted ${extractedLinks.length} Kwik embed URLs. Decrypting in parallel...');
          
          List<StreamSource> decryptedSources = [];
          List<String> decryptedQualities = [];
          
          await Future.wait(sources.map((src) async {
            try {
              final raw = await _bypassService.extractKwikVideoUrl(src.url);
              if (raw != null) {
                decryptedSources.add(StreamSource(
                  url: raw,
                  quality: src.quality,
                  isM3U8: raw.contains('.m3u8'),
                  isDub: src.isDub,
                ));
                final q = src.quality;
                if (!decryptedQualities.contains(q)) {
                  decryptedQualities.add(q);
                }
              }
            } catch (e) {
              _log('Error decrypting source ${src.url}: $e');
            }
          }));

          if (decryptedSources.isEmpty) {
            _log('Failed to decrypt any Kwik video links.');
            return null;
          }

          // Sort descending by quality (e.g. 1080p, 720p)
          decryptedSources.sort((a, b) {
            final resA = int.tryParse(a.quality.replaceAll(RegExp(r'\D'), '')) ?? 0;
            final resB = int.tryParse(b.quality.replaceAll(RegExp(r'\D'), '')) ?? 0;
            return resB.compareTo(resA);
          });

          String? directUrl;
          for (var src in decryptedSources) {
            bool isSub = !src.isDub;
            if ((subDub == 'sub' && isSub) || (subDub == 'dub' && !isSub)) {
              directUrl = src.url;
              break;
            }
          }
          directUrl ??= decryptedSources.first.url;
          
          final isM3U8 = directUrl.contains('.m3u8');
          _log('Returning StreamResult. Decrypted Direct URL: $directUrl (isM3U8: $isM3U8)');
          
          return StreamResult(
            url: directUrl,
            quality: 'auto',
            provider: 'AnimePahe',
            subtitles: [],
            availableQualities: decryptedQualities,
            isM3U8: isM3U8,
            headers: {
              'Referer': 'https://kwik.cx/',
              'User-Agent': _bypassService.userAgent,
            },
            sources: decryptedSources,
          );
        }
      }
      
      _log('Failed to find Kwik links in HTML.');
      return null;
      
    } catch (e) {
      _log('Animepahe Scraper Error: $e');
      return null;
    }
  }
}
