import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namizo/utils/image_url.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// An entry from the weekly airing schedule.
class AiringEntry {
  final int showId;
  final String showName;
  final String? posterPath;
  final DateTime airDate;
  final int lastEpisode;
  final int? totalEpisodes;
  final double? score;

  const AiringEntry({
    required this.showId,
    required this.showName,
    required this.posterPath,
    required this.airDate,
    required this.lastEpisode,
    required this.totalEpisodes,
    required this.score,
  });

  String get totalEpisodesText =>
      totalEpisodes != null && totalEpisodes! > 0 ? '$totalEpisodes' : '?';

  static AiringEntry? fromJson(Map<String, dynamic> json) {
    final id = (json['malid'] as num?)?.toInt();
    final unix = (json['time'] as num?)?.toInt();
    final title = json['title']?.toString();
    if (id == null || unix == null || title == null || title.trim().isEmpty) {
      return null;
    }

    return AiringEntry(
      showId: id,
      showName: title,
      posterPath: json['picture']?.toString(),
      airDate: DateTime.fromMillisecondsSinceEpoch(unix * 1000),
      lastEpisode: (json['lastep'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['totalep'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

// Grayscale matrix used to desaturate non-watchlisted shows.
const _grayscaleMatrix = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
]);

/// Card displayed for each show in the schedule list.
class ScheduleCard extends StatelessWidget {
  final AiringEntry entry;
  final bool inWatchlist;

  /// Pre-resolved banner URL from the parent (may be null/empty).
  final String? bannerUrl;

  const ScheduleCard({
    super.key,
    required this.entry,
    required this.inWatchlist,
    this.bannerUrl,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPoster = posterUrl(entry.posterPath);
    final resolvedBanner = posterUrl(bannerUrl);
    final backgroundUrl =
        resolvedBanner.isNotEmpty ? resolvedBanner : resolvedPoster;

    final progressText = '${entry.lastEpisode}/${entry.totalEpisodesText}';
    final yearText = '${entry.airDate.year}';
    final scoreText =
        entry.score != null ? entry.score!.toStringAsFixed(1) : '--';
    final timeText = DateFormat('EEE HH:mm').format(entry.airDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (greyed if not in watchlist)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: backgroundUrl.isNotEmpty
                ? (inWatchlist
                    ? CachedNetworkImage(
                        imageUrl: backgroundUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      )
                    : ColorFiltered(
                        colorFilter: _grayscaleMatrix,
                        child: CachedNetworkImage(
                          imageUrl: backgroundUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ))
                : const SizedBox.shrink(),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 1.0),
                  Colors.black.withValues(alpha: inWatchlist ? 0.60 : 0.9),
                  Colors.black.withValues(alpha: inWatchlist ? 0.25 : 0.8),
                ],
                stops: const [0.0, 0.70, 1.0],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Tappable content
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.push('/media/${entry.showId}?type=tv'),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    // Poster thumbnail
                    SizedBox(
                      height: 82,
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: resolvedPoster.isNotEmpty
                              ? (inWatchlist
                                  ? CachedNetworkImage(
                                      imageUrl: resolvedPoster,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: const Color(0xFF1D212B),
                                      ),
                                    )
                                  : ColorFiltered(
                                      colorFilter: _grayscaleMatrix,
                                      child: CachedNetworkImage(
                                        imageUrl: resolvedPoster,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: const Color(0xFF1D212B),
                                        ),
                                      ),
                                    ))
                              : Container(color: const Color(0xFF1D212B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Metadata column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: inWatchlist ? 30 : 0,
                                  ),
                                  child: Text(
                                    entry.showName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              _MetaChip(
                                icon: PhosphorIconsRegular.calendar,
                                text: yearText,
                              ),
                              _MetaChip(
                                icon: PhosphorIconsRegular.closedCaptioning,
                                text: progressText,
                              ),
                              _MetaChip(
                                icon: PhosphorIconsRegular.listNumbers,
                                text: entry.totalEpisodesText,
                              ),
                              _MetaChip(
                                icon: PhosphorIconsRegular.star,
                                text: scoreText,
                              ),
                              _MetaChip(
                                icon: PhosphorIconsRegular.clock,
                                text: timeText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
          // Watchlist badge
          if (inWatchlist)
            Positioned(
              top: 8,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: PhosphorIcon(
                        PhosphorIconsFill.bookmarkSimple,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

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
