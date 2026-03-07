import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/providers/dynamic_colors.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class RelatedMediaSection extends StatelessWidget {
  final Future<List<SearchResult>> relatedFuture;
  final DynamicColors colors;

  const RelatedMediaSection({
    super.key,
    required this.relatedFuture,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SearchResult>>(
      future: relatedFuture,
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
            'Failed to load related titles',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NamizoTheme.textTertiary),
          );
        }

        final items = (snapshot.data ?? const []).toList(growable: false);
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
                    'Oops! No related titles found',
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          padding: const EdgeInsets.only(top: 6),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildRelatedScheduleCard(context, item);
          },
        );
      },
    );
  }

  Widget _buildRelatedScheduleCard(BuildContext context, SearchResult item) {
    final resolvedImage =
        _resolveImageUrl(item.posterPath) ??
        _resolveImageUrl(item.backdropPath) ??
        '';
    final hasMalRoute = item.id > 0;
    final typeLabel = _relatedTypeLabel(item.mediaType);
    final scoreText = item.voteAverage != null
        ? item.voteAverage!.toStringAsFixed(1)
        : '--';
    final yearText = _relatedYearLabel(item);
    final typeIcon = _relatedTypeIcon(item.mediaType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: resolvedImage.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: resolvedImage,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  )
                : Container(color: const Color(0xFF1D212B)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 1.0),
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.28),
                ],
                stops: const [0.0, 0.70, 1.0],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: hasMalRoute
                  ? () => context.push(
                      '/media/${item.id}?type=${_detailType(item.mediaType)}',
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox(
                      height: 82,
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: resolvedImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: resolvedImage,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Container(color: const Color(0xFF1D212B)),
                                )
                              : Container(color: const Color(0xFF1D212B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title ?? item.name ?? 'Unknown',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              _RelatedMetaChip(icon: typeIcon, text: typeLabel),
                              _RelatedMetaChip(
                                icon: PhosphorIconsRegular.calendar,
                                text: yearText,
                              ),
                              _RelatedMetaChip(
                                icon: PhosphorIconsRegular.star,
                                text: scoreText,
                              ),
                              _RelatedMetaChip(
                                icon: hasMalRoute
                                    ? PhosphorIconsRegular.arrowSquareOut
                                    : PhosphorIconsRegular.lockSimple,
                                text: hasMalRoute ? 'Open' : 'Info',
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
          ),
        ],
      ),
    );
  }

  String? _resolveImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    if (imagePath.startsWith('/')) {
      return 'https://kuroiru.co$imagePath';
    }
    return imagePath;
  }

  String _relatedTypeLabel(String? sourceType) {
    switch ((sourceType ?? '').toLowerCase()) {
      case 'movie':
        return 'Movie';
      case 'ova':
        return 'OVA';
      case 'ona':
        return 'ONA';
      case 'special':
        return 'Special';
      default:
        return 'Show';
    }
  }

  IconData _relatedTypeIcon(String? sourceType) {
    switch ((sourceType ?? '').toLowerCase()) {
      case 'movie':
        return PhosphorIconsRegular.filmSlate;
      case 'ova':
      case 'ona':
      case 'special':
        return PhosphorIconsRegular.videoCamera;
      default:
        return PhosphorIconsRegular.television;
    }
  }

  String _relatedYearLabel(SearchResult item) {
    final raw = item.firstAirDate ?? item.releaseDate;
    if (raw == null || raw.length < 4) return '--';
    return raw.substring(0, 4);
  }

  String _detailType(String mediaType) {
    return mediaType.toLowerCase() == 'movie' ? 'movie' : 'tv';
  }
}

class _RelatedMetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RelatedMetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(icon, color: Colors.white54, size: 12),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
