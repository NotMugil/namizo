import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nivio/core/theme.dart';
import 'package:nivio/models/search_result.dart';
import 'package:nivio/providers/service_providers.dart';

class SearchResultCard extends ConsumerWidget {
  final SearchResult media;

  const SearchResultCard({super.key, required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmdbService = ref.watch(tmdbServiceProvider);
    final posterUrl = tmdbService.getPosterUrl(media.posterPath);
    final title = media.title ?? media.name ?? 'Unknown';
    final year = _getYear();
    final rating = media.voteAverage;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        context.push('/media/${media.id}?type=tv');
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          color: const Color(0xFF1A1A1A),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (posterUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: NivioTheme.netflixDarkGrey,
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: NivioTheme.netflixRed,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: NivioTheme.netflixDarkGrey,
                          child: const Icon(
                            Icons.movie_creation_outlined,
                            color: NivioTheme.netflixGrey,
                            size: 42,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: NivioTheme.netflixDarkGrey,
                        child: const Icon(
                          Icons.movie_creation_outlined,
                          color: NivioTheme.netflixGrey,
                          size: 42,
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (year != 'N/A')
                        Text(
                          year,
                          style: const TextStyle(
                            color: NivioTheme.netflixGrey,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (year != 'N/A' && rating != null && rating > 0)
                        const Text(
                          '  •  ',
                          style: TextStyle(
                            color: NivioTheme.netflixGrey,
                            fontSize: 11,
                          ),
                        ),
                      if (rating != null && rating > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Color(0xFFE9C46A),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: NivioTheme.netflixGrey,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getYear() {
    final date = media.releaseDate ?? media.firstAirDate;
    if (date != null && date.isNotEmpty && date.length >= 4) {
      return date.substring(0, 4);
    }
    return 'N/A';
  }
}
