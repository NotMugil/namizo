import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/models/search_result.dart';
import 'package:namizo/models/watchlist_item.dart';
import 'package:namizo/providers/dynamic_colors.dart';
import 'package:namizo/providers/media.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/watchlist.dart';
import 'package:namizo/services/tvdb.dart';
import 'package:share_plus/share_plus.dart';
import 'package:namizo/screens/media/trailer_overlay.dart';
import 'package:namizo/screens/media/episode_list.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MediaDetailScreen extends ConsumerStatefulWidget {
  final int mediaId;
  final String? mediaType;

  const MediaDetailScreen({super.key, required this.mediaId, this.mediaType});

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen>
  with SingleTickerProviderStateMixin {
  static const List<String> _detailTabs = ['Episodes', 'More Like This'];

  SearchResult? _media;
  List<String> _genres = const [];
  bool _aboutExpanded = false;
  bool _aboutOverflow = false;
  bool _isLoading = true;
  bool? _watchlistOverride;
  String? _error;
  String? _trailerUrl;
  String? _preferredBackdropUrl;
  String? _preferredPosterUrl;
  int _activeTabIndex = 0;
  Future<List<TvdbSimilarSeries>>? _similarSeriesFuture;
  late final TabController _detailTabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(length: _detailTabs.length, vsync: this);
    _detailTabController.addListener(() {
      if (!_detailTabController.indexIsChanging &&
          _activeTabIndex != _detailTabController.index) {
        setState(() => _activeTabIndex = _detailTabController.index);
      }
    });
    _fetchMediaDetails();
  }

  @override
  void dispose() {
    _detailTabController.dispose();
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

  String? _resolveImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    if (imagePath.startsWith('/')) {
      return 'https://kuroiru.co$imagePath';
    }
    return imagePath;
  }

  Future<void> _fetchMediaDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tmdbService = ref.read(kuroiruServiceProvider);
      _similarSeriesFuture = tmdbService.getTVShowSimilarFromTvdb(widget.mediaId);
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

      final artwork = await Future.wait<String?>([
        tmdbService.getTVShowCarouselImageUrl(widget.mediaId),
        tmdbService.getTVShowBannerUrl(widget.mediaId),
        tmdbService.getTVShowPosterUrl(widget.mediaId),
      ]);

      final preferredBackdrop = _resolveImageUrl(artwork[0]) ??
          _resolveImageUrl(artwork[1]) ??
          _resolveImageUrl(artwork[2]);
      final preferredPoster = _resolveImageUrl(artwork[2]);

      final trailerUrl = _extractTrailerKey(detailsWithVideos['videos']);
      final genres = (detailsWithVideos['genres'] as List<dynamic>? ?? [])
          .map((genre) => (genre as Map<String, dynamic>)['name'] as String?)
          .whereType<String>()
          .toList();

      setState(() {
        _media = mediaDetails;
        _trailerUrl = trailerUrl;
        _preferredBackdropUrl = preferredBackdrop;
        _preferredPosterUrl = preferredPoster;
        _genres = genres;
        _activeTabIndex = 0;
        _isLoading = false;
      });
      _detailTabController.animateTo(0);
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
          child: CircularProgressIndicator(color: NamizoTheme.netflixRed),
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
                const PhosphorIcon(
                  PhosphorIconsRegular.warningCircle,
                  color: NamizoTheme.netflixRed,
                  size: 56,
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
    final fallbackBackdropUrl = tmdbService.getBackdropUrl(media.backdropPath);
    final fallbackPosterUrl = tmdbService.getPosterUrl(media.posterPath);
    final backdropUrl =
      _preferredBackdropUrl ?? fallbackBackdropUrl ?? fallbackPosterUrl;
    final posterUrl = _preferredPosterUrl ?? fallbackPosterUrl;
    final watchlistState = ref.watch(isInWatchlistProvider(media.id));
    final isInWatchlist = _watchlistOverride ?? watchlistState;
    final colorsAsync = ref.watch(dynamicColorsProvider(posterUrl));
    final colors = colorsAsync.valueOrNull ?? DynamicColors.fallback;
    final visibleHeartColor = _visibleOnDark(colors.dominant);

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
                                  icon: const PhosphorIcon(
                                    PhosphorIconsRegular.caretLeft,
                                    color: NamizoTheme.netflixWhite,
                                    size: 20,
                                  ),
                                  onTap: () => context.pop(),
                                ),
                                Row(
                                  children: [
                                    _glassIconButton(
                                      icon: const PhosphorIcon(
                                        PhosphorIconsRegular.video,
                                        color: NamizoTheme.netflixWhite,
                                        size: 19,
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
                                      icon: const PhosphorIcon(
                                        PhosphorIconsRegular.shareNetwork,
                                        color: NamizoTheme.netflixWhite,
                                        size: 19,
                                      ),
                                      onTap: () async {
                                        final shareUrl =
                                            'https://myanimelist.net/anime/${media.id}';
                                        await Share.share(
                                          shareUrl,
                                          subject: mediaName,
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
                                      context.push(
                                        '/player/${media.id}?season=1&episode=1',
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _plainIconButton(
                                  icon: const Icon(
                                    Icons.favorite_border,
                                    color: NamizoTheme.netflixWhite,
                                    size: 24,
                                  ),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Favorites coming soon'),
                                      ),
                                    );
                                  },
                                ),
                                // Filled heart = in watchlist, outline = not
                                _plainIconButton(
                                  icon: Icon(
                                    isInWatchlist
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    color: isInWatchlist
                                        ? visibleHeartColor
                                        : NamizoTheme.netflixWhite,
                                    size: 24,
                                  ),
                                  iconColor: isInWatchlist
                                      ? visibleHeartColor
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
                                    color: NamizoTheme.netflixRed,
                                  ),
                                  label: const Text(
                                    'Watch trailer',
                                    style: TextStyle(
                                      color: NamizoTheme.netflixRed,
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

  Color _visibleOnDark(Color color) {
    if (color.computeLuminance() >= 0.25) {
      return color;
    }
    return Color.alphaBlend(Colors.white.withValues(alpha: 0.45), color);
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
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: NamizoTheme.glassFill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: NamizoTheme.netflixRed.withValues(alpha: 0.65),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIconsFill.play,
                    color: NamizoTheme.netflixRed,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Play all episodes',
                    style: TextStyle(
                      color: NamizoTheme.netflixRed,
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
    final shouldAutoSyncAniList =
      ref.read(aniListViewerProvider).valueOrNull != null &&
      ref.read(aniListAutoSyncProvider);
    final aniListService = ref.read(aniListServiceProvider);

    if (isInWatchlist) {
      if (mounted) {
        setState(() => _watchlistOverride = false);
      }

      await watchlistService.removeFromWatchlist(media.id);
      final hasAniListLogin =
          (await aniListService.getAccessToken())?.isNotEmpty == true;
      var aniListDeleted = true;
      if (hasAniListLogin) {
        aniListDeleted = await aniListService.removeFromTrackedByMalId(media.id);
        ref.read(aniListAccountRefreshProvider.notifier).state++;
      }

      ref.read(watchlistRefreshProvider.notifier).refresh();
      ref.invalidate(watchlistProvider);
      ref.invalidate(isInWatchlistProvider(media.id));
      if (!mounted) return;

      if (!aniListDeleted) {
        _showToast(
          message: 'Removed locally, but AniList delete failed',
          icon: PhosphorIconsRegular.warning,
          accent: const Color(0xFFF59E0B),
        );
        return;
      }

      _showToast(
        message: hasAniListLogin ? 'Removed from list' : 'Removed from watchlist',
        icon: PhosphorIconsRegular.bookmarkSimple,
        accent: const Color(0xFFEF4444),
      );
    } else {
      final localAlreadyExists = ref
          .read(watchlistProvider)
          .any((item) => item.id == media.id);
      final aniListAlreadyExists = ref
          .read(watchlistStatusByIdProvider)
          .containsKey(media.id);

      if (localAlreadyExists || aniListAlreadyExists) {
        if (mounted) {
          setState(() => _watchlistOverride = true);
        }
        _showToast(
          message: 'Already in your list',
          icon: PhosphorIconsFill.bookmarkSimple,
          accent: const Color(0xFF3B82F6),
        );
        return;
      }

      if (mounted) {
        setState(() => _watchlistOverride = true);
      }

      final item = WatchlistItem(
        id: media.id,
        title: media.title ?? media.name ?? 'Unknown',
        posterPath: media.posterPath,
        backdropPath: media.backdropPath,
        mediaType: media.mediaType,
        addedAt: DateTime.now(),
        voteAverage: media.voteAverage,
        releaseDate: media.releaseDate ?? media.firstAirDate,
        overview: media.overview,
      );
      await watchlistService.addToWatchlist(item);
      if (shouldAutoSyncAniList) {
        final synced = await aniListService.addToPlanningByMalId(media.id);
        if (synced) {
          ref.read(aniListAccountRefreshProvider.notifier).state++;
        }
      }
      ref.read(watchlistRefreshProvider.notifier).refresh();
      ref.invalidate(watchlistProvider);
      ref.invalidate(isInWatchlistProvider(media.id));
      if (!mounted) return;
      _showToast(
        message: 'Added to watchlist',
        icon: PhosphorIconsFill.bookmarkSimple,
        accent: const Color(0xFF22C55E),
      );
    }
  }

  void _showToast({
    required String message,
    required IconData icon,
    required Color accent,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        elevation: 0,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: 0.45), width: 1),
        ),
        content: Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTVControls(
    BuildContext context,
    SearchResult media,
    DynamicColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _detailTabController,
          isScrollable: false,
          indicatorColor: NamizoTheme.netflixRed,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: NamizoTheme.netflixWhite,
          unselectedLabelColor: NamizoTheme.netflixGrey,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Episodes'),
            Tab(text: 'More Like This'),
          ],
        ),
        SizedBox(height: _activeTabIndex == 0 ? 14 : 0),
        if (_activeTabIndex == 0)
          EpisodeList(
            media: media,
            season: 1,
            colors: colors,
            scrollController: _scrollController,
          )
        else
          _buildMoreLikeThis(media.id, colors),
      ],
    );
  }

  Widget _buildMoreLikeThis(int mediaId, DynamicColors colors) {
    _similarSeriesFuture ??= ref
        .read(kuroiruServiceProvider)
        .getTVShowSimilarFromTvdb(mediaId);

    return FutureBuilder<List<TvdbSimilarSeries>>(
      future: _similarSeriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: NamizoTheme.netflixRed),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Failed to load similar titles',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NamizoTheme.netflixLightGrey,
                ),
          );
        }

        final items = (snapshot.data ?? const [])
          .where((item) => (item.sourceType ?? 'anime').toLowerCase() == 'anime')
          .toList(growable: false);
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/oops.png',
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Oops! No similar matches found',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2 / 3,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildSimilarPoster(item);
          },
        );
      },
    );
  }

  Widget _buildSimilarPoster(TvdbSimilarSeries item) {
    final isAnime = (item.sourceType ?? 'anime') == 'anime';
    final hasMalRoute = item.malId != null && item.malId! > 0 && isAnime;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: hasMalRoute ? () => context.push('/media/${item.malId}?type=tv') : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: NamizoTheme.netflixDarkGrey,
                ),
                errorWidget: (context, url, error) => Container(
                  color: NamizoTheme.netflixDarkGrey,
                  child: const Icon(
                    Icons.movie_creation_outlined,
                    color: NamizoTheme.netflixGrey,
                  ),
                ),
              )
            : Container(
                color: NamizoTheme.netflixDarkGrey,
                child: const Icon(
                  Icons.movie_creation_outlined,
                  color: NamizoTheme.netflixGrey,
                ),
              ),
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
                    color: NamizoTheme.netflixRed,
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

