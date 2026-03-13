import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/models/media/search_result.dart';
import 'package:namizo/models/media/season_info.dart';
import 'package:namizo/providers/dynamic_colors.dart';
import 'package:namizo/providers/media.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class EpisodeList extends ConsumerStatefulWidget {
  final SearchResult media;
  final int season;
  final DynamicColors colors;
  final ScrollController? scrollController;
  final bool showEasterEggOops;

  const EpisodeList({
    super.key,
    required this.media,
    required this.season,
    required this.colors,
    this.scrollController,
    required this.showEasterEggOops,
  });

  @override
  ConsumerState<EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends ConsumerState<EpisodeList> {
  static const int _pageSize = 50;
  static const double _scrollThreshold = 400;

  String _searchQuery = '';
  _EpisodeRange? _selectedRange;
  int _displayedCount = _pageSize;
  bool _hasMore = false;
  bool _nearBottom = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(EpisodeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
    if (oldWidget.season != widget.season) {
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _selectedRange = null;
        _displayedCount = _pageSize;
        _nearBottom = false;
      });
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    final isNear = sc.position.extentAfter < _scrollThreshold;
    if (isNear && !_nearBottom && _hasMore) {
      _nearBottom = true;
      setState(() => _displayedCount += _pageSize);
    } else if (!isNear && _nearBottom) {
      _nearBottom = false;
    }
  }

  Future<void> _scrollToTop() async {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    await sc.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  List<_EpisodeRange> _buildRanges(List<EpisodeData> episodes) {
    if (episodes.isEmpty) return const [];
    final maxEpisode = episodes
        .map((ep) => ep.episodeNumber)
        .fold<int>(0, (max, value) => value > max ? value : max);
    if (maxEpisode <= 0) return const [];

    final bucketCount = (maxEpisode / 100).ceil();
    return List.generate(bucketCount, (index) {
      final start = index * 100;
      final end = (index + 1) * 100;
      return _EpisodeRange(start: start, end: end);
    });
  }

  Future<void> _openRangePicker(
    BuildContext context,
    List<_EpisodeRange> ranges,
  ) async {
    if (ranges.isEmpty) return;
    final current = _selectedRange;

    final selection = await showModalBottomSheet<_EpisodeRangeSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          bottom: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 2),
                  child: Text(
                    'Episode Range',
                    style: TextStyle(
                      color: NamizoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'Pick a 100-episode bucket',
                    style: TextStyle(
                      color: NamizoTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRangeChip(
                          label: 'All',
                          selected: current == null,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(const _EpisodeRangeSelection(range: null)),
                        ),
                        ...ranges.map(
                          (range) => _buildRangeChip(
                            label: range.label,
                            selected: current == range,
                            onTap: () => Navigator.of(
                              context,
                            ).pop(_EpisodeRangeSelection(range: range)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selection == null) return;
    final pickedRange = selection.range;
    if (pickedRange == _selectedRange) return;
    setState(() {
      _selectedRange = pickedRange;
      _displayedCount = _pageSize;
    });
    await _scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    final hideSpoilers = ref.watch(hideSpoilersProvider);
    final seasonDataAsync = ref.watch(
      seasonDataWithFallbackProvider((
        showId: widget.media.id,
        seasonNumber: widget.season,
      )),
    );

    return seasonDataAsync.when(
      data: (seasonData) {
        final ranges = _buildRanges(seasonData.episodes);
        final filteredByRange = _selectedRange == null
            ? seasonData.episodes
            : seasonData.episodes.where((ep) {
                final range = _selectedRange!;
                return ep.episodeNumber > range.start &&
                    ep.episodeNumber <= range.end;
              }).toList();

        final filteredEpisodes = _searchQuery.isEmpty
            ? filteredByRange
            : filteredByRange.where((ep) {
                final query = _searchQuery.toLowerCase();
                final name = ep.episodeName?.toLowerCase() ?? '';
                final number = ep.episodeNumber.toString();
                return name.contains(query) || number.contains(query);
              }).toList();

        _hasMore = filteredEpisodes.length > _displayedCount;
        final visibleEpisodes = filteredEpisodes.take(_displayedCount).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() {
                      _searchQuery = value;
                      _displayedCount = _pageSize;
                    }),
                    style: const TextStyle(
                      color: NamizoTheme.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search episodes',
                      hintStyle: const TextStyle(
                        color: NamizoTheme.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: NamizoTheme.textTertiary.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _displayedCount = _pageSize;
                                });
                              },
                              icon: Icon(
                                Icons.close,
                                color: NamizoTheme.textTertiary.withValues(
                                  alpha: 0.7,
                                ),
                                size: 18,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0x1FFFFFFF),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0x26FFFFFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: Color(0x667C73FF)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _openRangePicker(context, ranges),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _selectedRange == null
                              ? const Color(0x26FFFFFF)
                              : const Color(0x667C73FF),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt_rounded,
                            size: 16,
                            color: _selectedRange == null
                                ? NamizoTheme.textSecondary
                                : const Color(0xFFB5AEFF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedRange?.label ?? 'Range',
                            style: TextStyle(
                              color: _selectedRange == null
                                  ? NamizoTheme.textPrimary
                                  : const Color(0xFFE3E0FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filteredEpisodes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      widget.showEasterEggOops
                          ? Image.asset(
                              'assets/images/oops.png',
                              height: 72,
                              fit: BoxFit.contain,
                            )
                          : PhosphorIcon(
                              PhosphorIconsRegular.warningCircle,
                              color: widget.colors.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              size: 42,
                            ),
                      const SizedBox(height: 12),
                      Text(
                        'Oops! No episodes matches',
                        style: TextStyle(
                          color: widget.colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ...visibleEpisodes.asMap().entries.map(
                (entry) =>
                    _buildEpisodeCard(entry.key, entry.value, hideSpoilers),
              ),
              if (_hasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF7C73FF),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C73FF)),
      ),
      error: (err, stack) => Text(
        'Error loading episodes: $err',
        style: const TextStyle(color: NamizoTheme.textTertiary),
      ),
    );
  }

  Widget _buildEpisodeCard(int index, EpisodeData episode, bool hideSpoilers) {
    final stillUrl = episode.stillPath != null
        ? (episode.stillPath!.startsWith('http://') ||
                  episode.stillPath!.startsWith('https://')
              ? episode.stillPath!
              : episode.stillPath!.startsWith('/')
              ? 'https://kuroiru.co${episode.stillPath}'
              : episode.stillPath!)
        : '';

    final bgColor = index.isEven ? const Color(0x0EFFFFFF) : Colors.transparent;

    // An episode is unaired if its air date is in the future or unknown
    final isUnaired = _isUnaired(episode.airDate);

    final relDate = _relativeDate(episode.airDate);
    final episodeTitle = hideSpoilers
        ? 'Episode ${episode.episodeNumber}'
        : (episode.episodeName ?? 'Episode ${episode.episodeNumber}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Radial bloom behind thumbnail for aired episodes
          if (!isUnaired)
            Positioned(
              left: -30,
              top: -40,
              width: 240,
              height: 200,
              child: IgnorePointer(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 55,
                    sigmaY: 55,
                    tileMode: TileMode.decal,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.0,
                        colors: [
                          widget.colors.dominant.withValues(alpha: 0.18),
                          widget.colors.dominant.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                context.push(
                  '/player/${widget.media.id}?season=${widget.season}&episode=${episode.episodeNumber}',
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!isUnaired) ...[
                      SizedBox(
                        width: 130,
                        height: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: stillUrl.isNotEmpty
                                  ? ImageFiltered(
                                      imageFilter: hideSpoilers
                                          ? ImageFilter.blur(
                                              sigmaX: 10,
                                              sigmaY: 10,
                                            )
                                          : ImageFilter.blur(
                                              sigmaX: 0,
                                              sigmaY: 0,
                                            ),
                                      child: CachedNetworkImage(
                                        imageUrl: stillUrl,
                                        width: 140,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            _thumbPlaceholder(),
                                        errorWidget: (context, url, error) =>
                                            _thumbError(),
                                      ),
                                    )
                                  : _thumbError(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${episode.episodeNumber}. $episodeTitle',
                            style: const TextStyle(
                              fontSize: 12,
                              color: NamizoTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (relDate.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              relDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: isUnaired
                                    ? NamizoTheme.textSecondary.withValues(
                                        alpha: 0.6,
                                      )
                                    : NamizoTheme.textSecondary,
                              ),
                            ),
                          ],
                          if (!isUnaired &&
                              !hideSpoilers &&
                              episode.overview?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              episode.overview!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: NamizoTheme.textTertiary,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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

  bool _isUnaired(String? airDate) {
    if (airDate == null || airDate.isEmpty) return true;
    try {
      final date = DateTime.parse(airDate);
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      return DateTime(date.year, date.month, date.day).isAfter(today);
    } catch (_) {
      return true;
    }
  }

  String _relativeDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final target = DateTime(date.year, date.month, date.day);
      final diff = target.difference(today).inDays;

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff == -1) return 'Yesterday';

      if (diff > 0) {
        if (diff < 7) return 'In $diff days';
        if (diff < 14) return 'In 1 week';
        if (diff < 21) return 'In 2 weeks';
        if (diff < 28) return 'In 3 weeks';
        if (diff >= 365) {
          final years = (diff / 365.25).round();
          return 'In ${years == 1 ? '1 year' : '$years years'}';
        }
        final months = (diff / 30.5).round();
        return 'In ${months == 1 ? '1 month' : '$months months'}';
      } else {
        final abs = diff.abs();
        if (abs < 7) return '$abs days ago';
        if (abs < 14) return '1 week ago';
        if (abs < 21) return '2 weeks ago';
        if (abs < 28) return '3 weeks ago';
        if (abs >= 365) {
          final years = (abs / 365.25).round();
          return '${years == 1 ? '1 year' : '$years years'} ago';
        }
        final months = (abs / 30.5).round();
        return '${months == 1 ? '1 month' : '$months months'} ago';
      }
    } catch (_) {
      return '';
    }
  }

  Widget _thumbPlaceholder() => Container(
    width: 100,
    height: 75,
    color: const Color(0x33262C3D),
    child: const Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF7C73FF),
        ),
      ),
    ),
  );

  Widget _thumbError() => Container(
    width: 100,
    height: 75,
    color: const Color(0x33262C3D),
    child: const Icon(
      Icons.ondemand_video,
      color: NamizoTheme.textSecondary,
      size: 24,
    ),
  );

  Widget _buildRangeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0x367C73FF) : const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0x997C73FF)
                  : const Color(0x33FFFFFF),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFEAE7FF)
                  : NamizoTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeRange {
  final int start;
  final int end;

  const _EpisodeRange({required this.start, required this.end});

  String get label => '$start-$end';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _EpisodeRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class _EpisodeRangeSelection {
  final _EpisodeRange? range;

  const _EpisodeRangeSelection({required this.range});
}
