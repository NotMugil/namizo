import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/models/cache_entry.dart';
import 'package:namizo/models/watchlist_item.dart';
import 'package:namizo/models/new_episode.dart';
import 'package:namizo/core/cache/cache_service.dart';
import 'package:namizo/services/watchlist.dart';
import 'package:namizo/services/episode_check.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/ui/home/home.dart';
import 'package:namizo/ui/search/search.dart';
import 'package:namizo/ui/media/media_detail.dart';
import 'package:namizo/ui/common/main_shell.dart';
import 'package:namizo/ui/player/player.dart';
import 'package:namizo/ui/settings/settings.dart';
import 'package:namizo/ui/profile/anilist_login.dart';
import 'package:namizo/ui/profile/profile.dart';
import 'package:namizo/ui/calendar/new_episodes.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await _initHive();

  final cacheService = CacheService();
  await cacheService.init();

  await EpisodeCheckService.init();

  runApp(
    ProviderScope(
      overrides: [cacheServiceProvider.overrideWithValue(cacheService)],
      child: const NamizoApp(),
    ),
  );

  FlutterNativeSplash.remove();
}

Future<void> _initHive() async {
  await Hive.initFlutter();
  Hive.registerAdapter(CacheEntryAdapter());
  Hive.registerAdapter(WatchlistItemAdapter());
  Hive.registerAdapter(NewEpisodeAdapter());
  await WatchlistService.init();
}

final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/', redirect: (_, __) => '/home'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShellScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const NewEpisodesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/new-episodes', redirect: (_, __) => '/calendar'),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/anilist-login',
      builder: (context, state) => const AniListLoginScreen(),
    ),
    GoRoute(path: '/watchlist', redirect: (_, __) => '/profile'),
    GoRoute(
      path: '/media/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final mediaType = state.uri.queryParameters['type'];
        return MediaDetailScreen(mediaId: int.parse(id), mediaType: mediaType);
      },
    ),
    GoRoute(
      path: '/player/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final season = int.parse(state.uri.queryParameters['season'] ?? '1');
        final episode = int.parse(state.uri.queryParameters['episode'] ?? '1');
        final mediaType = state.uri.queryParameters['type'];
        return PlayerScreen(
          mediaId: int.parse(id),
          season: season,
          episode: episode,
          mediaType: mediaType,
        );
      },
    ),
  ],
);

class NamizoApp extends StatelessWidget {
  const NamizoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Namizo',
      theme: NamizoTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
