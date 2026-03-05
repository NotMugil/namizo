import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/models/search_result.dart';
import 'package:namizo/providers/services.dart';

class SearchResultCard extends ConsumerWidget {
  final SearchResult media;

  const SearchResultCard({super.key, required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmdbService = ref.watch(kuroiruServiceProvider);
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (posterUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    color: NamizoTheme.netflixDarkGrey,
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: NamizoTheme.netflixRed,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: NamizoTheme.netflixDarkGrey,
                    child: const Icon(
                      Icons.movie_creation_outlined,
                      color: NamizoTheme.netflixGrey,
                      size: 42,
                    ),
                  ),
                )
              else
                Container(
                  color: NamizoTheme.netflixDarkGrey,
                  child: const Icon(
                    Icons.movie_creation_outlined,
                    color: NamizoTheme.netflixGrey,
                    size: 42,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.45, 0.72, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (year != 'N/A')
                          Text(
                            year,
                            style: const TextStyle(
                              color: NamizoTheme.netflixLightGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (year != 'N/A' && rating != null && rating > 0)
                          const Text(
                            '  •  ',
                            style: TextStyle(
                              color: NamizoTheme.netflixLightGrey,
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
                                  color: NamizoTheme.netflixLightGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
