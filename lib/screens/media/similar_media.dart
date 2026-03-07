import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/models/tvdb/tvdb_models.dart';
import 'package:namizo/providers/dynamic_colors.dart';
import 'package:namizo/theme/theme.dart';

class SimilarMediaSection extends StatelessWidget {
  final Future<List<TvdbSimilarSeries>> similarFuture;
  final DynamicColors colors;

  const SimilarMediaSection({
    super.key,
    required this.similarFuture,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TvdbSimilarSeries>>(
      future: similarFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: NamizoTheme.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Failed to load similar titles',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NamizoTheme.textTertiary),
          );
        }

        final items = (snapshot.data ?? const [])
            .where(
              (item) => (item.sourceType ?? 'anime').toLowerCase() == 'anime',
            )
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
            return _buildSimilarPoster(context, item);
          },
        );
      },
    );
  }

  Widget _buildSimilarPoster(BuildContext context, TvdbSimilarSeries item) {
    final isAnime = (item.sourceType ?? 'anime') == 'anime';
    final hasMalRoute = item.malId != null && item.malId! > 0 && isAnime;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: hasMalRoute
          ? () => context.push('/media/${item.malId}?type=tv')
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: NamizoTheme.surface),
                errorWidget: (context, url, error) => Container(
                  color: NamizoTheme.surface,
                  child: const Icon(
                    Icons.movie_creation_outlined,
                    color: NamizoTheme.textSecondary,
                  ),
                ),
              )
            : Container(
                color: NamizoTheme.surface,
                child: const Icon(
                  Icons.movie_creation_outlined,
                  color: NamizoTheme.textSecondary,
                ),
              ),
      ),
    );
  }
}
