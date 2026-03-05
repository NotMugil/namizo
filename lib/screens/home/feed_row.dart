import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/core/defaults.dart';
import 'package:namizo/providers/home.dart';
import 'package:namizo/widgets/content_row.dart';

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
