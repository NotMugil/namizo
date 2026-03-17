import 'package:go_router/go_router.dart';
import 'package:namizo/routes/shell.dart';
import 'package:namizo/screens/home/home.dart';
import 'package:namizo/screens/search/search.dart';
import 'package:namizo/screens/media/media.dart';
import 'package:namizo/screens/player/player.dart';
import 'package:namizo/screens/settings/settings.dart';
import 'package:namizo/screens/profile/anilist_login.dart';
import 'package:namizo/screens/profile/profile.dart';
import 'package:namizo/screens/schedule/new_episodes.dart';
import 'package:namizo/screens/schedule/schedule.dart';
import 'package:namizo/screens/watchlist/watchlist.dart';

final appRouter = GoRouter(
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
              builder: (context, state) => SearchScreen(
                initialQuery: state.uri.queryParameters['q'],
                initialFeedKey: state.uri.queryParameters['feed'],
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/watchlist',
              builder: (context, state) => const WatchlistScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const ScheduleScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(path: '/new-episodes', redirect: (_, __) => '/notifications'),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/anilist-login',
      builder: (context, state) => const AniListLoginScreen(),
    ),
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
