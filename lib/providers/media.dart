import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/models/search_result.dart';
import 'package:namizo/models/season_info.dart';
import 'package:namizo/providers/services.dart';

// Selected media state
final selectedMediaProvider = StateProvider<SearchResult?>((ref) => null);

// Selected season state
final selectedSeasonProvider = StateProvider<int>((ref) => 1);

// Selected episode state
final selectedEpisodeProvider = StateProvider<int>((ref) => 1);

// Selected quality state
final selectedQualityProvider = StateProvider<String?>((ref) => null);

// Series info provider (for TV shows)
final seriesInfoProvider = FutureProvider.family<SeriesInfo, int>((ref, showId) async {
  final tmdb = ref.watch(kuroiruServiceProvider);
  return await tmdb.getSeriesInfo(showId);
});

// Season data provider (episodes for a specific season)
final seasonDataProvider = FutureProvider.family<SeasonData, ({int showId, int seasonNumber})>((ref, params) async {
  final tmdb = ref.watch(kuroiruServiceProvider);
  return await tmdb.getSeasonInfo(params.showId, params.seasonNumber);
});
