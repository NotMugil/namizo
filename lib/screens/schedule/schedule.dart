import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/providers/watchlist.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/screens/schedule/schedule_card.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _weekAnchor = DateTime.now();
  List<AiringEntry> _allAiring = const [];
  List<AiringEntry> _selectedWeekAniListAiring = const [];
  final Map<String, List<AiringEntry>> _aniListWeekCache = {};
  final Map<int, String?> _tvdbBannerByShowId = {};
  final Set<int> _loadingTvdbBannerIds = <int>{};
  bool _isLoading = true;
  bool _isWeekLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshSchedule();
  }

  Future<void> _refreshSchedule() async {
    setState(() => _isLoading = true);
    try {
      final raw = await ref.read(kuroiruServiceProvider).getAiringCalendar();
      final parsed =
          raw
              .map(AiringEntry.fromJson)
              .whereType<AiringEntry>()
              .toList(growable: false)
            ..sort((a, b) => a.airDate.compareTo(b.airDate));
      if (!mounted) return;
      setState(() {
        _allAiring = parsed;
        _isLoading = false;
      });
      await _loadSelectedWeekAniListEntries();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allAiring = const [];
        _isLoading = false;
      });
      await _loadSelectedWeekAniListEntries();
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  List<AiringEntry> _weeklyEntries(List<AiringEntry> source) {
    final weekStart = _startOfWeek(_weekAnchor);
    final weekEnd = weekStart.add(const Duration(days: 7));

    return source
        .where((entry) {
          final air = DateTime(
            entry.airDate.year,
            entry.airDate.month,
            entry.airDate.day,
            entry.airDate.hour,
            entry.airDate.minute,
          );
          return !air.isBefore(weekStart) && air.isBefore(weekEnd);
        })
        .toList(growable: false);
  }

  List<_DaySection> _groupByWeek(
    DateTime weekStart,
    List<AiringEntry> entries,
  ) {
    final grouped = <DateTime, List<AiringEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.airDate.year,
        entry.airDate.month,
        entry.airDate.day,
      );
      grouped.putIfAbsent(day, () => <AiringEntry>[]).add(entry);
    }

    return List<_DaySection>.generate(7, (index) {
      final day = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      ).add(Duration(days: index));
      final key = DateTime(day.year, day.month, day.day);
      return _DaySection(
        day: key,
        entries: grouped[key] ?? const <AiringEntry>[],
      );
    }, growable: false);
  }

  void _changeWeek(int offsetDays) {
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: offsetDays));
    });
    _loadSelectedWeekAniListEntries();
  }

  Future<void> _loadSelectedWeekAniListEntries() async {
    final weekStart = _startOfWeek(_weekAnchor);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final cacheKey = DateFormat('yyyy-MM-dd').format(weekStart);

    final cached = _aniListWeekCache[cacheKey];
    if (cached != null) {
      setState(() {
        _selectedWeekAniListAiring = cached;
        _isWeekLoading = false;
      });
      _primeWeekBannerUrls(
        _mergeWeekEntries(_weeklyEntries(_allAiring), cached),
      );
      return;
    }

    setState(() => _isWeekLoading = true);
    try {
      final raw = await ref
          .read(aniListServiceProvider)
          .getAiringScheduleRange(start: weekStart, end: weekEnd);

      final parsed =
          raw
              .map(AiringEntry.fromJson)
              .whereType<AiringEntry>()
              .toList(growable: false)
            ..sort((a, b) => a.airDate.compareTo(b.airDate));

      if (!mounted) return;
      _aniListWeekCache[cacheKey] = parsed;
      setState(() {
        _selectedWeekAniListAiring = parsed;
        _isWeekLoading = false;
      });
      _primeWeekBannerUrls(
        _mergeWeekEntries(_weeklyEntries(_allAiring), parsed),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedWeekAniListAiring = const [];
        _isWeekLoading = false;
      });
      _primeWeekBannerUrls(
        _mergeWeekEntries(_weeklyEntries(_allAiring), const []),
      );
    }
  }

  Future<void> _primeWeekBannerUrls(List<AiringEntry> entries) async {
    final ids = entries
        .map((entry) => entry.showId)
        .where((id) => id > 0)
        .toSet();
    final pending = ids
        .where(
          (id) =>
              !_tvdbBannerByShowId.containsKey(id) &&
              !_loadingTvdbBannerIds.contains(id),
        )
        .toList(growable: false);
    if (pending.isEmpty) return;

    _loadingTvdbBannerIds.addAll(pending);
    final kuroiruService = ref.read(kuroiruServiceProvider);
    final fetched = await Future.wait(
      pending.map((id) async {
        try {
          final banner = await kuroiruService.getTVShowBannerUrl(id);
          return MapEntry<int, String?>(id, banner);
        } catch (_) {
          return MapEntry<int, String?>(id, null);
        }
      }),
    );
    if (!mounted) return;

    setState(() {
      for (final entry in fetched) {
        _tvdbBannerByShowId[entry.key] = entry.value;
        _loadingTvdbBannerIds.remove(entry.key);
      }
    });
  }

  List<AiringEntry> _mergeWeekEntries(
    List<AiringEntry> primary,
    List<AiringEntry> secondary,
  ) {
    final mergedByKey = <String, AiringEntry>{};
    final slotToCanonical = <String, String>{};

    for (final entry in [...primary, ...secondary]) {
      final episodeKey = entry.lastEpisode > 0
          ? '${entry.showId}_ep_${entry.lastEpisode}'
          : null;
      final slotKey =
          '${entry.showId}_slot_${DateFormat('yyyy-MM-dd_HH').format(entry.airDate)}';

      final canonicalKey =
          (episodeKey != null && mergedByKey.containsKey(episodeKey))
          ? episodeKey
          : slotToCanonical[slotKey] ?? episodeKey ?? slotKey;

      final existing = mergedByKey[canonicalKey];
      if (existing == null) {
        mergedByKey[canonicalKey] = entry;
        slotToCanonical[slotKey] = canonicalKey;
        continue;
      }

      mergedByKey[canonicalKey] = _preferEnglishTitle(existing, entry);
      slotToCanonical[slotKey] = canonicalKey;
    }

    final merged = mergedByKey.values.toList(growable: false);
    merged.sort((a, b) => a.airDate.compareTo(b.airDate));
    return merged;
  }

  bool _hasJapaneseTitle(String title) {
    return RegExp(r'[\u3040-\u30FF\u3400-\u9FFF]').hasMatch(title);
  }

  AiringEntry _preferEnglishTitle(AiringEntry current, AiringEntry next) {
    final currentHasJapanese = _hasJapaneseTitle(current.showName);
    final nextHasJapanese = _hasJapaneseTitle(next.showName);

    if (currentHasJapanese && !nextHasJapanese) {
      return next;
    }
    if (!currentHasJapanese && nextHasJapanese) {
      return current;
    }

    return current;
  }

  String _weekLabel() {
    final start = _startOfWeek(_weekAnchor);
    final end = start.add(const Duration(days: 6));
    final startText = DateFormat('MMM d').format(start);
    final endText = DateFormat('MMM d').format(end);
    return '$startText - $endText';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = EpisodeCheckService.getUnreadCount();
    final trackedOnlyInSchedule = ref.watch(scheduleTrackedOnlyProvider);
    final trackedHintDismissed = ref.watch(
      scheduleTrackedHintDismissedProvider,
    );
    final aniListTrackedIdsAsync = ref.watch(aniListTrackedIdsProvider);
    final watchlistIds = ref.watch(watchlistProvider).map((e) => e.id).toSet();
    final trackedIds = {
      ...watchlistIds,
      ...?aniListTrackedIdsAsync.valueOrNull,
    };

    final weekEntries = _mergeWeekEntries(
      _weeklyEntries(_allAiring),
      _selectedWeekAniListAiring,
    );
    final entries = trackedOnlyInSchedule
        ? weekEntries
              .where((entry) => trackedIds.contains(entry.showId))
              .toList(growable: false)
        : weekEntries;
    final weekStart = _startOfWeek(_weekAnchor);
    final sections = _groupByWeek(weekStart, entries);

    return Scaffold(
      backgroundColor: NamizoTheme.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        backgroundColor: NamizoTheme.background,
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
                        color: NamizoTheme.primary,
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
          if (!trackedHintDismissed)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: PhosphorIcon(
                      PhosphorIconsRegular.info,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tip: You can show only tracked anime for schedule in Settings.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            await ref
                                .read(
                                  scheduleTrackedHintDismissedProvider.notifier,
                                )
                                .dismissForever();
                            if (!context.mounted) return;
                            context.push('/settings');
                          },
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(
                              color: NamizoTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    onPressed: () {
                      ref
                          .read(scheduleTrackedHintDismissedProvider.notifier)
                          .dismissForever();
                    },
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
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
                      (_isLoading || _isWeekLoading)
                          ? 'Loading weekly schedule...'
                          : 'No scheduled episodes this week',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
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
                        if (section.entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                            child: Text(
                              'No scheduled episodes',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          for (final entry in section.entries)
                            ScheduleCard(
                              entry: entry,
                              inWatchlist: watchlistIds.contains(entry.showId),
                              bannerUrl: _tvdbBannerByShowId[entry.showId],
                            ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DaySection {
  final DateTime day;
  final List<AiringEntry> entries;

  const _DaySection({required this.day, required this.entries});
}
