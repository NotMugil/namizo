import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/providers/settingsproviders.dart';
import 'package:namizo/providers/watchlistprovider.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _weekAnchor = DateTime.now();
  List<_AiringEntry> _allAiring = const [];
  bool _isLoading = true;
  final Map<int, String?> _bannerByShowId = {};

  @override
  void initState() {
    super.initState();
    _refreshSchedule();
  }

  Future<void> _refreshSchedule() async {
    setState(() => _isLoading = true);
    try {
      final raw = await ref.read(kuroiruServiceProvider).getAiringCalendar();
      final parsed = raw
          .map(_AiringEntry.fromJson)
          .whereType<_AiringEntry>()
          .toList(growable: false)
        ..sort((a, b) => a.airDate.compareTo(b.airDate));
      if (!mounted) return;
      setState(() {
        _allAiring = parsed;
        _isLoading = false;
      });
      _ensureBannerUrls(_weeklyEntries(parsed).map((entry) => entry.showId).toSet());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allAiring = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _ensureBannerUrls(Set<int> showIds) async {
    final missingIds = showIds.where((id) => !_bannerByShowId.containsKey(id)).toList();
    if (missingIds.isEmpty) return;

    final service = ref.read(kuroiruServiceProvider);
    final fetched = <int, String?>{};

    await Future.wait(
      missingIds.map((showId) async {
        try {
          fetched[showId] = await service.getTVShowBannerUrl(showId);
        } catch (_) {
          fetched[showId] = null;
        }
      }),
    );

    if (!mounted) return;
    setState(() {
      _bannerByShowId.addAll(fetched);
    });
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - DateTime.monday));
  }

  List<_AiringEntry> _weeklyEntries(List<_AiringEntry> source) {
    final weekStart = _startOfWeek(_weekAnchor);
    final weekEnd = weekStart.add(const Duration(days: 7));

    return source.where((entry) {
      final air = DateTime(
        entry.airDate.year,
        entry.airDate.month,
        entry.airDate.day,
        entry.airDate.hour,
        entry.airDate.minute,
      );
      return !air.isBefore(weekStart) && air.isBefore(weekEnd);
    }).toList(growable: false);
  }

  List<_DaySection> _groupByDay(List<_AiringEntry> entries) {
    final grouped = <DateTime, List<_AiringEntry>>{};
    for (final entry in entries) {
      final day = DateTime(entry.airDate.year, entry.airDate.month, entry.airDate.day);
      grouped.putIfAbsent(day, () => <_AiringEntry>[]).add(entry);
    }

    final sortedDays = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    return sortedDays
        .map((day) => _DaySection(day: day, entries: grouped[day]!))
        .toList(growable: false);
  }

  void _changeWeek(int offsetDays) {
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: offsetDays));
    });
    _ensureBannerUrls(
      _weeklyEntries(_allAiring).map((entry) => entry.showId).toSet(),
    );
  }

  String _weekLabel() {
    final start = _startOfWeek(_weekAnchor);
    final end = start.add(const Duration(days: 6));
    final startText = DateFormat('MMM d').format(start);
    final endText = DateFormat('MMM d').format(end);
    return '$startText - $endText';
  }

  String _normalizedPoster(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return 'https://kuroiru.co$path';
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = EpisodeCheckService.getUnreadCount();
    final trackedOnlyInSchedule = ref.watch(scheduleTrackedOnlyProvider);
    final aniListTrackedIdsAsync = ref.watch(aniListTrackedIdsProvider);
    final watchlistIds = ref.watch(watchlistProvider).map((e) => e.id).toSet();
    final trackedIds = {
      ...watchlistIds,
      ...?aniListTrackedIdsAsync.valueOrNull,
    };

    final weekEntries = _weeklyEntries(_allAiring);
    final entries = trackedOnlyInSchedule
        ? weekEntries
              .where((entry) => trackedIds.contains(entry.showId))
              .toList(growable: false)
        : weekEntries;
    final sections = _groupByDay(entries);

    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: NamizoTheme.netflixBlack,
        automaticallyImplyLeading: false,
        title: Text(
          'Schedule',
          style: NamizoTheme.pageHeaderStyle.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: Stack(
              children: [
                const PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  color: Colors.white,
                  size: 22,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: NamizoTheme.netflixRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeWeek(-7),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.caretLeft,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: Text(
                    _weekLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeWeek(7),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.caretRight,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      _isLoading
                          ? 'Loading weekly schedule...'
                          : 'No scheduled episodes this week',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      for (final section in sections) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                          child: Text(
                            DateFormat('EEEE • MMM d').format(section.day),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final entry in section.entries)
                          _buildScheduleCard(
                            context: context,
                            entry: entry,
                            inWatchlist: watchlistIds.contains(entry.showId),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({
    required BuildContext context,
    required _AiringEntry entry,
    required bool inWatchlist,
  }) {
    final posterUrl = _normalizedPoster(entry.posterPath);
    final bannerUrl = _normalizedPoster(_bannerByShowId[entry.showId]);
    final backgroundUrl = bannerUrl.isNotEmpty ? bannerUrl : posterUrl;
    final progressText = '${entry.lastEpisode}/${entry.totalEpisodesText}';
    final totalText = entry.totalEpisodesText;
    final yearText = '${entry.airDate.year}';
    final scoreText = entry.score != null ? entry.score!.toStringAsFixed(1) : '--';
    final timeText = DateFormat('EEE HH:mm').format(entry.airDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
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
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: CachedNetworkImage(
                          imageUrl: backgroundUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ))
                : const SizedBox.shrink(),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 1.0),
                  Colors.black.withValues(alpha: inWatchlist ? 0.45 : 0.9),
                  Colors.black.withValues(alpha: inWatchlist ? 0.25 : 0.8),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.push('/media/${entry.showId}?type=tv'),
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
                          child: posterUrl.isNotEmpty
                              ? (inWatchlist
                                  ? CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: const Color(0xFF1D212B),
                                      ),
                                    )
                                  : ColorFiltered(
                                      colorFilter: const ColorFilter.matrix(<double>[
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0.2126,
                                        0.7152,
                                        0.0722,
                                        0,
                                        0,
                                        0,
                                        0,
                                        0,
                                        1,
                                        0,
                                      ]),
                                      child: CachedNetworkImage(
                                        imageUrl: posterUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: const Color(0xFF1D212B),
                                        ),
                                      ),
                                    ))
                              : Container(
                                  color: const Color(0xFF1D212B),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: inWatchlist ? 30 : 0),
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
                              _metaChip(
                                icon: PhosphorIconsRegular.calendar,
                                text: yearText,
                              ),
                              _metaChip(
                                icon: PhosphorIconsRegular.closedCaptioning,
                                text: progressText,
                              ),
                              _metaChip(
                                icon: PhosphorIconsRegular.listNumbers,
                                text: totalText,
                              ),
                              _metaChip(
                                icon: PhosphorIconsRegular.star,
                                text: scoreText,
                              ),
                              _metaChip(
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

  Widget _metaChip({required IconData icon, required String text}) {
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

class _AiringEntry {
  final int showId;
  final String showName;
  final String? posterPath;
  final DateTime airDate;
  final int lastEpisode;
  final int? totalEpisodes;
  final double? score;

  const _AiringEntry({
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

  static _AiringEntry? fromJson(Map<String, dynamic> json) {
    final id = (json['malid'] as num?)?.toInt();
    final unix = (json['time'] as num?)?.toInt();
    final title = json['title']?.toString();
    if (id == null || unix == null || title == null || title.trim().isEmpty) {
      return null;
    }

    return _AiringEntry(
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

class _DaySection {
  final DateTime day;
  final List<_AiringEntry> entries;

  const _DaySection({required this.day, required this.entries});
}
