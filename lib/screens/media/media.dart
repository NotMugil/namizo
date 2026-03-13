import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/models/user/watchlist_item.dart';
import 'package:namizo/models/tvdb/tvdb_models.dart';
import 'package:namizo/providers/dynamic_colors.dart';
import 'package:namizo/providers/media.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/watchlist.dart';
import 'package:share_plus/share_plus.dart';
import 'package:namizo/screens/media/trailer_overlay.dart';
import 'package:namizo/screens/media/episode_list.dart';
import 'package:namizo/screens/media/related_media.dart';
import 'package:namizo/screens/media/similar_media.dart';
import 'package:namizo/widgets/toast.dart';
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
  static const List<String> _detailTabs = ['Episodes', 'Related', 'Similar'];

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
  Future<List<SearchResult>>? _relatedSeriesFuture;
  Future<List<TvdbSimilarSeries>>? _similarSeriesFuture;
  late final TabController _detailTabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(
      length: _detailTabs.length,
      vsync: this,
    );
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

  String? _normalizeYoutubeUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    final youtubeIdPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
    if (youtubeIdPattern.hasMatch(value)) {
      return 'https://www.youtube.com/watch?v=$value';
    }

    final match = RegExp(
      r'(https?:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/)[a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1);
  }

  String? _extractTrailerKey(dynamic videosData) {
    if (videosData == null) return null;
    final results = videosData['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    for (final video in results) {
      if (video['site'] == 'YouTube' && video['type'] == 'Trailer') {
        final trailerUrl = _normalizeYoutubeUrl(video['key']?.toString());
        if (trailerUrl != null) return trailerUrl;
      }
    }

    for (final video in results) {
      if (video['site'] == 'YouTube') {
        final trailerUrl = _normalizeYoutubeUrl(video['key']?.toString());
        if (trailerUrl != null) return trailerUrl;
      }
    }

    return null;
  }

  String? _extractTrailerUrl(Map<String, dynamic> detailsData) {
    final fromVideos = _extractTrailerKey(detailsData['videos']);
    if (fromVideos != null) return fromVideos;

    final directCandidates = <dynamic>[
      detailsData['trailer_url'],
      detailsData['yt'],
      detailsData['trailer'],
      detailsData['youtube'],
    ];
    for (final candidate in directCandidates) {
      final trailerUrl = _normalizeYoutubeUrl(candidate?.toString());
      if (trailerUrl != null) return trailerUrl;
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
      _relatedSeriesFuture = ref
          .read(aniListServiceProvider)
          .getRelatedAnimeByMalId(widget.mediaId);
      _similarSeriesFuture = tmdbService.getTVShowSimilarFromTvdb(
        widget.mediaId,
      );
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

      final preferredBackdrop =
          _resolveImageUrl(artwork[0]) ??
          _resolveImageUrl(artwork[1]) ??
          _resolveImageUrl(artwork[2]);
      final preferredPoster = _resolveImageUrl(artwork[2]);

      final trailerUrl = _extractTrailerUrl(detailsWithVideos);
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
        backgroundColor: NamizoTheme.background,
        appBar: AppBar(backgroundColor: NamizoTheme.background, elevation: 0),
        body: const Center(
          child: CircularProgressIndicator(color: NamizoTheme.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: NamizoTheme.background,
        appBar: AppBar(backgroundColor: NamizoTheme.background, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PhosphorIcon(
                  PhosphorIconsRegular.warningCircle,
                  color: NamizoTheme.primary,
                  size: 56,
                ),
                const SizedBox(height: 14),
                const Text('Failed to load details'),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: NamizoTheme.textSecondary),
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
    final backdropUrl = _preferredBackdropUrl ?? fallbackBackdropUrl;
    final posterUrl = _preferredPosterUrl ?? fallbackPosterUrl;
    final watchlistState = ref.watch(isInWatchlistProvider(media.id));
    final isInWatchlist = _watchlistOverride ?? watchlistState;
    final colorsAsync = ref.watch(dynamicColorsProvider(posterUrl));
    final colors = colorsAsync.valueOrNull ?? DynamicColors.fallback;
    final visibleHeartColor = _visibleOnDark(colors.dominant);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final heroHeight = screenHeight * 0.42;
    final year =
        media.releaseDate?.substring(0, 4) ??
        media.firstAirDate?.substring(0, 4) ??
        'Unknown';
    final mediaName = media.title ?? media.name ?? 'Unknown';

    return Scaffold(
      backgroundColor: NamizoTheme.background,
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
                                    color: NamizoTheme.textPrimary,
                                    size: 20,
                                  ),
                                  onTap: () => context.pop(),
                                ),
                                Row(
                                  children: [
                                    _glassIconButton(
                                      icon: const PhosphorIcon(
                                        PhosphorIconsRegular.video,
                                        color: NamizoTheme.textPrimary,
                                        size: 19,
                                      ),
                                      onTap: () {
                                        if (_trailerUrl != null) {
                                          _showTrailerPlayer(context);
                                          return;
                                        }
                                        AppToast.show(
                                          context: context,
                                          message:
                                              'Trailer unavailable for this anime',
                                          icon: PhosphorIconsRegular.warning,
                                          accent: const Color(0xFFF59E0B),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _glassIconButton(
                                      icon: const PhosphorIcon(
                                        PhosphorIconsRegular.shareNetwork,
                                        color: NamizoTheme.textPrimary,
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
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: NamizoTheme.textPrimary,
                                    height: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            // Genre subtext — wraps to next line on overflow
                            Text(
                              _buildGenreMeta(year),
                              style: const TextStyle(
                                color: NamizoTheme.textTertiary,
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
                                    color: NamizoTheme.textPrimary,
                                    size: 24,
                                  ),
                                  onTap: () {
                                    AppToast.show(
                                      context: context,
                                      message: 'Favorites coming soon',
                                      icon: Icons.favorite_border,
                                      accent: const Color(0xFF3B82F6),
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
                                        : NamizoTheme.textPrimary,
                                    size: 24,
                                  ),
                                  iconColor: isInWatchlist
                                      ? visibleHeartColor
                                      : NamizoTheme.textPrimary,
                                  onTap: () =>
                                      _toggleWatchlist(media, isInWatchlist),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'About',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: NamizoTheme.textPrimary,
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
              color: NamizoTheme.textPrimary,
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
    Color iconColor = NamizoTheme.textPrimary,
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
                  color: NamizoTheme.primary.withValues(alpha: 0.65),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIconsFill.play,
                    color: NamizoTheme.primary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Play all episodes',
                    style: TextStyle(
                      color: NamizoTheme.primary,
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
    final hasAniListLogin = ref.read(aniListViewerProvider).valueOrNull != null;
    final autoSyncAniList = ref.read(aniListAutoSyncProvider);
    final shouldAutoSyncAniList = hasAniListLogin && autoSyncAniList;
    final aniListService = ref.read(aniListServiceProvider);

    if (isInWatchlist) {
      final localAlreadyExists = ref
          .read(watchlistProvider)
          .any((item) => item.id == media.id);
      final aniListAlreadyExists = ref
          .read(watchlistStatusByIdProvider)
          .containsKey(media.id);
      final canManageStatuses = hasAniListLogin && autoSyncAniList;
      final action = await _showWatchlistActionSheet(
        canManageStatuses: canManageStatuses,
      );
      if (action == null) return;

      if (action == _WatchlistAction.remove) {
        if (mounted) {
          setState(() => _watchlistOverride = false);
        }
        if (localAlreadyExists) {
          await watchlistService.removeFromWatchlist(media.id);
        }

        var aniListDeleted = true;
        if (hasAniListLogin && aniListAlreadyExists) {
          aniListDeleted = await aniListService.removeFromTrackedByMalId(
            media.id,
          );
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
          message: hasAniListLogin
              ? 'Removed from list'
              : 'Removed from watchlist',
          icon: PhosphorIconsRegular.bookmarkSimple,
          accent: const Color(0xFFEF4444),
        );
        return;
      }

      final status = switch (action) {
        _WatchlistAction.dropped => 'DROPPED',
        _WatchlistAction.paused => 'PAUSED',
        _WatchlistAction.completed => 'COMPLETED',
        _WatchlistAction.remove => null,
      };
      if (status == null) return;

      final updated = await aniListService.updateStatusByMalId(
        malId: media.id,
        status: status,
      );
      if (!updated) {
        if (!mounted) return;
        _showToast(
          message: 'Failed to update status',
          icon: PhosphorIconsRegular.warning,
          accent: const Color(0xFFF59E0B),
        );
        return;
      }

      if (localAlreadyExists) {
        await watchlistService.removeFromWatchlist(media.id);
      }
      if (mounted) {
        setState(() => _watchlistOverride = true);
      }
      ref.read(aniListAccountRefreshProvider.notifier).state++;
      ref.read(watchlistRefreshProvider.notifier).refresh();
      ref.invalidate(watchlistProvider);
      ref.invalidate(isInWatchlistProvider(media.id));
      if (!mounted) return;
      _showToast(
        message: 'Moved to ${_statusLabel(status)}',
        icon: PhosphorIconsFill.checkCircle,
        accent: const Color(0xFF22C55E),
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

      final artwork = await aniListService.getArtworkByMalId(media.id);
      final item = WatchlistItem(
        id: media.id,
        title: media.title ?? media.name ?? 'Unknown',
        posterPath: artwork?.posterPath ?? media.posterPath,
        backdropPath: artwork?.backdropPath ?? media.backdropPath,
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
    AppToast.show(
      context: context,
      message: message,
      icon: icon,
      accent: accent,
    );
  }

  Future<_WatchlistAction?> _showWatchlistActionSheet({
    required bool canManageStatuses,
  }) {
    return showModalBottomSheet<_WatchlistAction>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Update bookmark',
                    style: TextStyle(
                      color: NamizoTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (canManageStatuses) ...[
                  _buildActionTile(
                    context: context,
                    label: 'Move to Dropped',
                    icon: PhosphorIconsRegular.xCircle,
                    iconColor: const Color(0xFFF87171),
                    action: _WatchlistAction.dropped,
                  ),
                  _buildActionTile(
                    context: context,
                    label: 'Move to Paused',
                    icon: PhosphorIconsRegular.pauseCircle,
                    iconColor: const Color(0xFFFBBF24),
                    action: _WatchlistAction.paused,
                  ),
                  _buildActionTile(
                    context: context,
                    label: 'Move to Completed',
                    icon: PhosphorIconsRegular.checkCircle,
                    iconColor: const Color(0xFF34D399),
                    action: _WatchlistAction.completed,
                  ),
                ],
                _buildActionTile(
                  context: context,
                  label: 'Remove entry',
                  icon: PhosphorIconsRegular.trash,
                  iconColor: const Color(0xFFEF4444),
                  action: _WatchlistAction.remove,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required _WatchlistAction action,
  }) {
    return ListTile(
      dense: true,
      onTap: () => Navigator.of(context).pop(action),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: PhosphorIcon(icon, color: iconColor, size: 18),
      title: Text(
        label,
        style: const TextStyle(
          color: NamizoTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DROPPED':
        return 'Dropped';
      case 'PAUSED':
        return 'Paused';
      case 'COMPLETED':
        return 'Completed';
      default:
        return status;
    }
  }

  Widget _buildTVControls(
    BuildContext context,
    SearchResult media,
    DynamicColors colors,
  ) {
    final showEasterEggOops = ref.watch(easterEggHomeLogoProvider);
    final kuroiruService = ref.read(kuroiruServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TabBar(
          controller: _detailTabController,
          isScrollable: false,
          indicatorColor: NamizoTheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: NamizoTheme.textPrimary,
          unselectedLabelColor: NamizoTheme.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Episodes'),
            Tab(text: 'Related'),
            Tab(text: 'Similar'),
          ],
        ),
        SizedBox(height: _activeTabIndex == 0 ? 14 : 0),
        if (_activeTabIndex == 0)
          EpisodeList(
            media: media,
            season: 1,
            colors: colors,
            scrollController: _scrollController,
            showEasterEggOops: showEasterEggOops,
          )
        else if (_activeTabIndex == 1)
          RelatedMediaSection(
            relatedFuture: _relatedSeriesFuture ??= ref
                .read(aniListServiceProvider)
                .getRelatedAnimeByMalId(media.id),
            colors: colors,
            kuroiruService: kuroiruService,
            showEasterEggOops: showEasterEggOops,
          )
        else
          SimilarMediaSection(
            similarFuture: _similarSeriesFuture ??= ref
                .read(kuroiruServiceProvider)
                .getTVShowSimilarFromTvdb(media.id),
            colors: colors,
            showEasterEggOops: showEasterEggOops,
          ),
      ],
    );
  }

  Widget _buildAboutSection(String aboutText) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: NamizoTheme.textTertiary,
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
              overflow: _aboutExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
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
                    color: NamizoTheme.primary,
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

enum _WatchlistAction { dropped, paused, completed, remove }
