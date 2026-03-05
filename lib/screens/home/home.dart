import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:namizo/providers/home.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/screens/home/banner.dart';
import 'package:namizo/screens/home/feed_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarBackground = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 50;
      if (show != _showAppBarBackground) {
        setState(() => _showAppBarBackground = show);
      }
    });
    unawaited(_prewarmHomeContent());
  }

  Future<void> _prewarmHomeContent() async {
    await Future.wait([
      ref.read(featuredAnimeProvider.future),
      ref.read(popularAnimeProvider.future),
      ref.read(trendingAnimeProvider.future),
      ref.read(topRatedAnimeProvider.future),
      ref.read(romanceAnimeProvider.future),
      ref.read(actionAnimeProvider.future),
      ref.read(adventureAnimeProvider.future),
      ref.read(fantasyAnimeProvider.future),
      ref.read(featuredAnimeLogosProvider.future),
      ref.read(featuredAnimePostersProvider.future),
    ]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featuredContent = ref.watch(featuredAnimeProvider);
    final featuredLogos = ref.watch(featuredAnimeLogosProvider);
    final featuredPosters = ref.watch(featuredAnimePostersProvider);
    final homeFeedOrder = ref.watch(homeFeedOrderProvider);
    final aniListViewerAsync = ref.watch(aniListViewerProvider);
    final easterEggEnabled = ref.watch(easterEggHomeLogoProvider);

    // Precache logo/poster images as soon as URLs are resolved
    ref.listen(featuredAnimeLogosProvider, (_, next) {
      next.whenData((logos) {
        for (final url in logos.values) {
          if (url != null && url.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(url), context);
          }
        }
      });
    });
    ref.listen(featuredAnimePostersProvider, (_, next) {
      next.whenData((posters) {
        for (final url in posters.values) {
          if (url != null && url.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(url), context);
          }
        }
      });
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _showAppBarBackground ? 12 : 0,
                sigmaY: _showAppBarBackground ? 12 : 0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _showAppBarBackground
                      ? const Color(0x6A0D0F14)
                      : Colors.transparent,
                  border: _showAppBarBackground
                      ? const Border(
                          bottom: BorderSide(color: Color(0x22FFFFFF)),
                        )
                      : null,
                  gradient: _showAppBarBackground
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                ),
              ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4),
            child: easterEggEnabled
                ? Image.asset(
                    'assets/images/nami.png',
                    height: 26,
                    fit: BoxFit.contain,
                  )
                : const Text(
                    'Namizo.',
                    style: TextStyle(
                      color: NamizoTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _NotificationBell(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _ProfileButton(aniListViewerAsync: aniListViewerAsync),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        cacheExtent: 1000,
        slivers: [
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: featuredContent.when(
                data: (content) {
                  final postersReady = featuredPosters.hasValue &&
                      !featuredPosters.isLoading &&
                      (featuredPosters.valueOrNull?.isNotEmpty ?? false);

                  if (!postersReady) return const HeroBannerShimmer();

                  return HeroBannerCarousel(
                    items: content,
                    logos: featuredLogos.value ?? {},
                    posters: featuredPosters.valueOrNull ?? const <int, String?>{},
                  );
                },
                loading: () => const HeroBannerShimmer(),
                error: (_, __) => const SizedBox(height: 500),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF141414), Color(0xFF0D0F14)],
                ),
              ),
            ),
          ),
          // Ordered content feed rows (includes Your List + Planning + Continue Watching)
          ...buildOrderedFeedRowSlivers(homeFeedOrder),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }
}

// ─── App bar action widgets ──────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = EpisodeCheckService.getUnreadCount();
    return Stack(
      children: [
        IconButton(
          icon: unreadCount > 0
              ? const PhosphorIcon(
                  PhosphorIconsFill.bellSimpleRinging,
                  color: Colors.white,
                  size: 22,
                )
              : const PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  color: Colors.white,
                  size: 22,
                ),
          tooltip: 'New Episodes',
          onPressed: () => context.push('/notifications'),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFE50914),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> aniListViewerAsync;

  const _ProfileButton({required this.aniListViewerAsync});

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        aniListViewerAsync.valueOrNull?['avatar']?['large']?.toString() ??
            aniListViewerAsync.valueOrNull?['avatar']?['medium']?.toString();

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return IconButton(
        tooltip: 'Profile',
        onPressed: () => context.go('/profile'),
        icon: CircleAvatar(
          radius: 12,
          backgroundColor: Colors.white24,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
        ),
      );
    }

    return IconButton(
      icon: const PhosphorIcon(
        PhosphorIconsRegular.userCircle,
        color: Colors.white,
        size: 24,
      ),
      tooltip: 'Profile',
      onPressed: () => context.go('/profile'),
    );
  }
}
