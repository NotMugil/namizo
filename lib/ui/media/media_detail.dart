import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart'
    hide Text, List, Map, Timer, Navigator, Page, Radius;
import 'package:namizo/theme/theme.dart';
import 'package:namizo/models/search_result.dart';
import 'package:namizo/models/season_info.dart';
import 'package:namizo/models/watchlist_item.dart';
import 'package:namizo/providers/dynamiccolorsprovider.dart';
import 'package:namizo/providers/mediaprovider.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/providers/watchlistprovider.dart';
import 'package:namizo/ui/media/widgets/episode_list.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

class MediaDetailScreen extends ConsumerStatefulWidget {
  final int mediaId;
  final String? mediaType;

  const MediaDetailScreen({super.key, required this.mediaId, this.mediaType});

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  SearchResult? _media;
  List<String> _genres = const [];
  bool _aboutExpanded = false;
  bool _aboutOverflow = false;
  bool _isLoading = true;
  String? _error;
  String? _trailerUrl;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMediaDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String? _extractTrailerKey(dynamic videosData) {
    if (videosData == null) return null;
    final results = videosData['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    for (final video in results) {
      if (video['site'] == 'YouTube' &&
          video['type'] == 'Trailer' &&
          video['official'] == true) {
        return 'https://www.youtube.com/watch?v=${video['key']}';
      }
    }
    return null;
  }

  Future<void> _fetchMediaDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tmdbService = ref.read(kuroiruServiceProvider);
      Map<String, dynamic>? detailsWithVideos;

      int retries = 3;
      Duration delay = const Duration(milliseconds: 500);

      for (int attempt = 0; attempt < retries; attempt++) {
        try {
          detailsWithVideos = await tmdbService.getTVShowDetailsWithVideos(
            widget.mediaId,
          );
          detailsWithVideos['media_type'] = 'tv';
          break;
        } catch (e) {
          if (attempt == retries - 1) rethrow;
          await Future.delayed(delay);
          delay *= 2;
        }
      }

      final mediaDetails = SearchResult.fromJson(detailsWithVideos!);
      ref.read(selectedMediaProvider.notifier).state = mediaDetails;
      final trailerUrl = _extractTrailerKey(detailsWithVideos['videos']);
      final genres = (detailsWithVideos['genres'] as List<dynamic>? ?? [])
          .map((genre) => (genre as Map<String, dynamic>)['name'] as String?)
          .whereType<String>()
          .toList();

      setState(() {
        _media = mediaDetails;
        _trailerUrl = trailerUrl;
        _genres = genres;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showTrailerPlayer(BuildContext context) {
    if (_trailerUrl == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: TrailerOverlay(youtubeUrl: _trailerUrl!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: NamizoTheme.netflixBlack,
        appBar: AppBar(backgroundColor: NamizoTheme.netflixBlack, elevation: 0),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C73FF)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: NamizoTheme.netflixBlack,
        appBar: AppBar(backgroundColor: NamizoTheme.netflixBlack, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const WarningCircle(
                  color: Color(0xFF9D96FF),
                  width: 56,
                  height: 56,
                ),
                const SizedBox(height: 14),
                const Text('Failed to load details'),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: NamizoTheme.netflixGrey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _fetchMediaDetails,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final media = _media;
    if (media == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tmdbService = ref.read(kuroiruServiceProvider);
    final backdropUrl = tmdbService.getBackdropUrl(media.backdropPath);
    final posterUrl = tmdbService.getPosterUrl(media.posterPath);
    final isInWatchlist = ref.watch(isInWatchlistProvider(media.id));
    final colorsAsync = ref.watch(dynamicColorsProvider(posterUrl));
    final colors = colorsAsync.valueOrNull ?? DynamicColors.fallback;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = screenHeight * 0.42;
    final year = media.releaseDate?.substring(0, 4) ??
        media.firstAirDate?.substring(0, 4) ??
        'Unknown';
    final mediaName = media.title ?? media.name ?? 'Unknown';

    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Radial gradient bloom ──────────────────────────────────
                // Dominant color "leaks" from the hero image like light
                // emitting from the artwork. Fades to transparent by ~150px
                // below the image bottom. Very low opacity, heavily blurred.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: heroHeight + 150,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 64,
                      sigmaY: 64,
                      tileMode: TileMode.decal,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.4,
                          colors: [
                            colors.dominant.withValues(alpha: 0.20),
                            colors.dominant.withValues(alpha: 0.07),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.40, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Main content ───────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (backdropUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: backdropUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  Container(color: colors.darkMuted),
                            )
                          else
                            Container(color: colors.darkMuted),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x4D000000),
                                  Color(0x990D0F14),
                                  Color(0xFF0D0F14),
                                ],
                                stops: [0.0, 0.7, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            top: MediaQuery.paddingOf(context).top + 4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _glassIconButton(
                                  icon: const NavArrowLeft(
                                    color: NamizoTheme.netflixWhite,
                                    width: 20,
                                    height: 20,
                                  ),
                                  onTap: () => context.pop(),
                                ),
                                Row(
                                  children: [
                                    _glassIconButton(
                                      icon: const MediaVideo(
                                        color: NamizoTheme.netflixWhite,
                                        width: 19,
                                        height: 19,
                                      ),
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Cast coming soon'),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _glassIconButton(
                                      icon: const ShareAndroid(
                                        color: NamizoTheme.netflixWhite,
                                        width: 19,
                                        height: 19,
                                      ),
                                      onTap: () async {
                                        final shareUrl =
                                            'https://myanimelist.net/anime/${media.id}';
                                        await Clipboard.setData(
                                          ClipboardData(text: shareUrl),
                                        );
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Link copied to clipboard',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 20,
                            child: Row(
                              children: [
                                _glassTag('PG-13'),
                                const SizedBox(width: 8),
                                _glassTag('24 min'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x000D0F14),
                              Color(0xCC0D0F14),
                              Color(0xFF0D0F14),
                            ],
                            stops: [0, 0.22, 0.42],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mediaName,
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: NamizoTheme.netflixWhite,
                                    height: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            // Genre subtext — wraps to next line on overflow
                            Text(
                              _buildGenreMeta(year),
                              style: const TextStyle(
                                color: NamizoTheme.netflixLightGrey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _playAllButton(
                                    onTap: () {
                                      final season =
                                          ref.read(selectedSeasonProvider);
                                      context.push(
                                        '/player/${media.id}?season=$season&episode=1',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Filled heart = in watchlist, outline = not
                                _plainIconButton(
                                  icon: Icon(
                                    isInWatchlist
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isInWatchlist
                                        ? colors.dominant
                                        : NamizoTheme.netflixWhite,
                                    size: 24,
                                  ),
                                  iconColor: isInWatchlist
                                      ? colors.dominant
                                      : NamizoTheme.netflixWhite,
                                  onTap: () =>
                                      _toggleWatchlist(media, isInWatchlist),
                                ),
                              ],
                            ),
                            if (_trailerUrl != null) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _showTrailerPlayer(context),
                                  icon: const Icon(
                                    Icons.play_circle_outline,
                                    size: 17,
                                    color: Color(0xFFB9B0FF),
                                  ),
                                  label: const Text(
                                    'Watch trailer',
                                    style: TextStyle(
                                      color: Color(0xFFB9B0FF),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Text(
                              'About',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: NamizoTheme.netflixWhite,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            _buildAboutSection(
                              media.overview?.isNotEmpty == true
                                  ? media.overview!
                                  : 'No description available for this title yet.',
                            ),
                            const SizedBox(height: 26),
                            _buildTVControls(context, media, colors),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton({
    required Widget icon,
    required VoidCallback onTap,
    double size = 44,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Material(
          color: const Color(0x26FFFFFF),
          shape: const CircleBorder(
            side: BorderSide(color: Color(0x33FFFFFF), width: 1),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassTag(String label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x4DFFFFFF)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: NamizoTheme.netflixWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _buildGenreMeta(String year) {
    final topGenres = _genres.take(3).toList();
    if (topGenres.isEmpty) return year;
    return '${topGenres.join(' | ')} | $year';
  }

  Widget _plainIconButton({
    required Widget icon,
    required VoidCallback onTap,
    Color iconColor = NamizoTheme.netflixWhite,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: icon,
      splashRadius: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _playAllButton({required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: const Color(0xFF7C73FF),
          child: InkWell(
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Play(color: Colors.white, width: 16, height: 16),
                  SizedBox(width: 8),
                  Text(
                    'Play all episodes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleWatchlist(SearchResult media, bool isInWatchlist) async {
    final watchlistService = ref.read(watchlistServiceProvider);

    if (isInWatchlist) {
      await watchlistService.removeFromWatchlist(media.id);
      ref.read(watchlistRefreshProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from watchlist'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      final item = WatchlistItem(
        id: media.id,
        title: media.title ?? media.name ?? 'Unknown',
        posterPath: media.posterPath,
        mediaType: media.mediaType,
        addedAt: DateTime.now(),
        voteAverage: media.voteAverage,
        releaseDate: media.releaseDate ?? media.firstAirDate,
        overview: media.overview,
      );
      await watchlistService.addToWatchlist(item);
      ref.read(watchlistRefreshProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to watchlist'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildTVControls(
    BuildContext context,
    SearchResult media,
    DynamicColors colors,
  ) {
    final seriesInfoAsync = ref.watch(seriesInfoProvider(media.id));

    return seriesInfoAsync.when(
      data: (seriesInfo) {
        final selectedSeason = ref.watch(selectedSeasonProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Episodes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: NamizoTheme.netflixWhite,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  width: 154,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x241F2431),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x36FFFFFF)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isDense: true,
                      value: selectedSeason <= seriesInfo.seasons.length
                          ? selectedSeason
                          : 1,
                      dropdownColor: NamizoTheme.netflixDarkGrey,
                      borderRadius: BorderRadius.circular(14),
                      icon: const Icon(
                        Icons.expand_more,
                        color: NamizoTheme.netflixWhite,
                      ),
                      style: const TextStyle(
                        color: NamizoTheme.netflixWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      items: seriesInfo.seasons
                          .where((s) => s.seasonNumber > 0)
                          .map(
                            (season) => DropdownMenuItem(
                              value: season.seasonNumber,
                              child: Text('Season ${season.seasonNumber}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        ref.read(selectedSeasonProvider.notifier).state = value;
                        ref.read(selectedEpisodeProvider.notifier).state = 1;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            EpisodeList(
              media: media,
              season: selectedSeason,
              colors: colors,
              scrollController: _scrollController,
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C73FF)),
      ),
      error: (err, stack) => Text(
        'Error loading seasons: $err',
        style: const TextStyle(color: NamizoTheme.netflixLightGrey),
      ),
    );
  }

  Widget _buildAboutSection(String aboutText) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: NamizoTheme.netflixLightGrey,
      height: 1.45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: aboutText, style: style),
          maxLines: 4,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = textPainter.didExceedMaxLines;
        if (_aboutOverflow != hasOverflow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _aboutOverflow = hasOverflow);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              aboutText,
              style: style,
              maxLines: _aboutExpanded ? null : 4,
              overflow:
                  _aboutExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (_aboutOverflow) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  setState(() => _aboutExpanded = !_aboutExpanded);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _aboutExpanded ? 'Read less' : 'Read more',
                  style: const TextStyle(
                    color: Color(0xFFB9B0FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class TrailerOverlay extends StatefulWidget {
  final String youtubeUrl;

  const TrailerOverlay({super.key, required this.youtubeUrl});

  @override
  State<TrailerOverlay> createState() => _TrailerOverlayState();
}

class _TrailerOverlayState extends State<TrailerOverlay> {
  bool _isLoading = true;
  String? _streamUrl;
  String? _error;

  String? _extractYoutubeVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  @override
  void initState() {
    super.initState();
    _fetchStreamUrl();
  }

  Future<void> _fetchStreamUrl() async {
    final videoId = _extractYoutubeVideoId(widget.youtubeUrl);
    if (videoId == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Invalid YouTube URL';
        _isLoading = false;
      });
      return;
    }

    try {
      final ytClient = yt.YoutubeExplode();
      final manifest = await ytClient.videos.streamsClient.getManifest(videoId);
      ytClient.close();

      final muxed = manifest.muxed.sortByVideoQuality();
      if (muxed.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _streamUrl = muxed.last.url.toString();
          _isLoading = false;
        });
        return;
      }

      final videoOnly = manifest.videoOnly.sortByVideoQuality();
      if (videoOnly.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _streamUrl = videoOnly.last.url.toString();
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = 'No streams available';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load trailer';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 450),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF7C73FF),
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    if (_error != null || _streamUrl == null) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 450),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Text(
              _error ?? 'Unable to play trailer',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final videoHtml = '''
<!DOCTYPE html>
<html><head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>*{margin:0;padding:0;background:#000}html,body{height:100%;width:100%;overflow:hidden}video{width:100%;height:100%;object-fit:contain}</style>
</head><body>
<video src="${_streamUrl!}" autoplay playsinline controls></video>
</body></html>
''';

    return Container(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 450),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: videoHtml,
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
                initialSettings: InAppWebViewSettings(
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  transparentBackground: true,
                  javaScriptEnabled: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
