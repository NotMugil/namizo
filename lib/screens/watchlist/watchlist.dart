import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/providers/watchlist.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/theme/theme.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  int _selectedStatusIndex = 0;

  @override
  Widget build(BuildContext context) {
    final watchlist = ref.watch(watchlistProvider);
    final grouped = ref.watch(watchlistGroupedByStatusProvider);
    final theme = Theme.of(context);
    final tmdbService = ref.watch(kuroiruServiceProvider);
    const statuses = ['WATCHING', 'PLANNING', 'PAUSED', 'DROPPED', 'COMPLETED'];

    final titleWidget = Text(
      'My Watchlist',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 18,
      ),
    );

    const actions = <Widget>[];

    if (watchlist.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: titleWidget,
          actions: actions,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bookmark_border,
                size: 120,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'Your watchlist is empty',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add anime to watch later',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedStatus = statuses[_selectedStatusIndex];

    return Scaffold(
      appBar: AppBar(
        title: titleWidget,
        actions: actions,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedStatusIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_statusLabel(statuses[index])),
                    selected: isSelected,
                    onSelected: (_) {
                      if (!isSelected) {
                        setState(() => _selectedStatusIndex = index);
                      }
                    },
                    showCheckmark: false,
                    side: BorderSide(
                      color: isSelected
                          ? NamizoTheme.netflixRed.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    shape: const StadiumBorder(),
                    selectedColor: NamizoTheme.netflixRed.withValues(alpha: 0.2),
                    backgroundColor: const Color(0xFF1A1A1A),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? NamizoTheme.netflixWhite
                          : NamizoTheme.netflixGrey,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _buildStatusGrid(
              context,
              grouped[selectedStatus] ?? const [],
              tmdbService,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(BuildContext context, List<dynamic> items, dynamic tmdbService) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No titles here yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: NamizoTheme.netflixGrey,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final posterUrl = tmdbService.getPosterUrl(item.posterPath);
        final artworkUrl = posterUrl;
        final year = _extractYear(item.releaseDate);
        final rating = item.voteAverage;

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.push('/media/${item.id}?type=${item.mediaType}');
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
                  if (artworkUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: artworkUrl,
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
                          item.title,
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
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PLANNING':
        return 'Planned';
      case 'PAUSED':
        return 'Paused';
      case 'DROPPED':
        return 'Dropped';
      case 'COMPLETED':
        return 'Completed';
      case 'WATCHING':
      default:
        return 'Watching';
    }
  }

  String _extractYear(String? date) {
    if (date != null && date.isNotEmpty && date.length >= 4) {
      return date.substring(0, 4);
    }
    return 'N/A';
  }
}
