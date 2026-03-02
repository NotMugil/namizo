import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nivio/core/theme.dart';
import 'package:nivio/models/cache_entry.dart';
import 'package:nivio/models/watchlist_item.dart';
import 'package:nivio/models/new_episode.dart';
import 'package:nivio/services/cache_service.dart';
import 'package:nivio/services/watchlist_service.dart';
import 'package:nivio/services/episode_check_service.dart';
import 'package:nivio/providers/service_providers.dart';
import 'package:nivio/screens/home_screen.dart';
import 'package:nivio/screens/search_screen.dart';
import 'package:nivio/screens/media_detail_screen.dart';
import 'package:nivio/screens/main_shell_screen.dart';
import 'package:nivio/screens/player_screen.dart';
import 'package:nivio/screens/settings_screen.dart';
import 'package:nivio/screens/anilist_login_screen.dart';
import 'package:nivio/screens/profile_screen.dart';
import 'package:nivio/screens/new_episodes_screen.dart';

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
      child: const NivioApp(),
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

class NivioApp extends StatelessWidget {
  const NivioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nivio',
      theme: NivioTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
