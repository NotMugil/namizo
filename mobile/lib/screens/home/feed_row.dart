import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/core/defaults.dart';
import 'package:namizo/providers/home.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/watch_history.dart';
import 'package:namizo/providers/watchlist.dart';
import 'package:namizo/widgets/content_row.dart';
import 'package:namizo/widgets/continue_watching_row.dart';

/// Builds all ordered feed row slivers based on [order] from settings.
List<Widget> buildOrderedFeedRowSlivers(List<String> order) {
  final normalized =
      order.isEmpty ? UserConfig.defaultHomeFeedOrder : order;

  return normalized
      .map(_buildFeedSliverForKey)
      .whereType<Widget>()
      .toList(growable: false);
}

Widget? _buildFeedSliverForKey(String key) {
  return switch (key) {
    'yourList' => _yourListSliver(),
    'planning' => _planningSliver(),
    'continueWatching' => _continueWatchingSliver(),
    'popular' => _asyncRowSliver(
        provider: popularAnimeProvider,
        title: 'All Time Popular',
      ),
    'trending' => _asyncRowSliver(
        provider: trendingAnimeProvider,
        title: 'Trending Now',
      ),
    'topRated' => _asyncRowSliver(
        provider: topRatedAnimeProvider,
        title: 'Top Rated Anime',
      ),
    'romance' => _asyncRowSliver(
        provider: romanceAnimeProvider,
        title: 'Romance',
      ),
    'action' => _asyncRowSliver(
        provider: actionAnimeProvider,
        title: 'Action',
      ),
    'adventure' => _asyncRowSliver(
        provider: adventureAnimeProvider,
        title: 'Adventure',
      ),
    'fantasy' => _asyncRowSliver(
        provider: fantasyAnimeProvider,
        title: 'Fantasy',
      ),
    _ => null,
  };
}

Widget _planningSliver() {
  return SliverToBoxAdapter(
    child: Consumer(
      builder: (context, ref, _) {
        return ref.watch(aniListPlanningProvider).when(
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : ContentRow(
                      title: 'Planning to Watch',
                      items: items,
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
      },
    ),
  );
}

Widget _yourListSliver() {
  return SliverToBoxAdapter(
    child: Consumer(
      builder: (context, ref, _) {
        final watchlist = ref
            .watch(watchlistProvider)
            .where((item) => item.mediaType == 'tv')
            .toList(growable: false);
        if (watchlist.isEmpty) return const SizedBox.shrink();

        final seenIds = <int>{};
        final watchlistItems = watchlist
            .where((item) => seenIds.add(item.id))
            .map(
              (item) => {
                'id': item.id,
                'name': item.title,
                'title': item.title,
                'poster_path': item.posterPath,
                'vote_average': item.voteAverage,
                'first_air_date': item.releaseDate,
                'media_type': 'tv',
              },
            )
            .toList(growable: false);

        return ContentRow(title: 'Your List', items: watchlistItems);
      },
    ),
  );
}

Widget _continueWatchingSliver() {
  return SliverToBoxAdapter(
    child: Consumer(
      builder: (context, ref, _) {
        return ref.watch(continueWatchingProvider).when(
              data: (items) => items.length <= 1
                  ? const SizedBox.shrink()
                  : const Padding(
                      padding: EdgeInsets.only(top: 0, left: 16, right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Continue Watching',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          ContinueWatchingRow(),
                          SizedBox(height: 30),
                        ],
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
      },
    ),
  );
}

Widget _asyncRowSliver({
  required FutureProvider<List<dynamic>> provider,
  required String title,
}) {
  return SliverToBoxAdapter(
    child: Consumer(
      builder: (context, ref, _) {
        return ref.watch(provider).when(
              data: (shows) => ContentRow(title: title, items: shows),
              loading: () => const SizedBox(height: 220),
              error: (_, __) => const SizedBox.shrink(),
            );
      },
    ),
  );
}
