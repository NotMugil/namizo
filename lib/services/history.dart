import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:namizo/core/config.dart';
import 'package:namizo/models/watch_history.dart';

class WatchHistoryService {
  late Box<String> _historyBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _historyBox = await Hive.openBox<String>(AppConfigurations.watchHistoryBoxName);
    _initialized = true;
  }

  Future<void> updateProgress({
    required int tmdbId,
    required String mediaType,
    required String title,
    String? posterPath,
    required int currentSeason,
    required int currentEpisode,
    required int totalSeasons,
    int? totalEpisodes,
    required Duration lastPosition,
    required Duration totalDuration,
  }) async {
    if (!_initialized) await init();

    final key = '$tmdbId';
    final progressPercent = totalDuration.inSeconds > 0
        ? lastPosition.inSeconds / totalDuration.inSeconds
        : 0.0;

    WatchHistory history;
    final existingJson = _historyBox.get(key);
    if (existingJson != null) {
      final existing = WatchHistory.fromJson(
        Map<String, dynamic>.from(_parseJson(existingJson)),
      );
      history = existing.copyWith(
        currentSeason: currentSeason,
        currentEpisode: currentEpisode,
        totalSeasons: totalSeasons,
        totalEpisodes: totalEpisodes,
        lastPositionSeconds: lastPosition.inSeconds,
        totalDurationSeconds: totalDuration.inSeconds,
        progressPercent: progressPercent,
        lastWatchedAt: DateTime.now(),
        isCompleted: progressPercent >= 0.95,
      );
    } else {
      history = WatchHistory(
        id: key,
        tmdbId: tmdbId,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        currentSeason: currentSeason,
        currentEpisode: currentEpisode,
        totalSeasons: totalSeasons,
        totalEpisodes: totalEpisodes,
        lastPositionSeconds: lastPosition.inSeconds,
        totalDurationSeconds: totalDuration.inSeconds,
        progressPercent: progressPercent,
        lastWatchedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isCompleted: false,
        episodes: {},
      );
    }

    if (mediaType == 'tv') {
      final episodeKey = 's${currentSeason}e$currentEpisode';
      final episodeProgress = EpisodeProgress(
        season: currentSeason,
        episode: currentEpisode,
        lastPositionSeconds: lastPosition.inSeconds,
        totalDurationSeconds: totalDuration.inSeconds,
        isCompleted: progressPercent >= 0.95,
        watchedAt: DateTime.now(),
      );
      final updatedEpisodes = Map<String, EpisodeProgress>.from(history.episodes);
      updatedEpisodes[episodeKey] = episodeProgress;
      history = history.copyWith(episodes: updatedEpisodes);
    }

    await _historyBox.put(key, _toJsonString(history.toJson()));
  }

  Future<List<WatchHistory>> getAllHistory() async {
    if (!_initialized) await init();
    final histories = <WatchHistory>[];
    for (final key in _historyBox.keys) {
      final json = _historyBox.get(key as String);
      if (json != null) {
        histories.add(
          WatchHistory.fromJson(Map<String, dynamic>.from(_parseJson(json))),
        );
      }
    }
    histories.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    return histories;
  }

  Future<List<WatchHistory>> getContinueWatching() async {
    final all = await getAllHistory();
    return all.where((h) => !h.isCompleted).take(10).toList();
  }

  Future<WatchHistory?> getHistory(int tmdbId) async {
    if (!_initialized) await init();
    final json = _historyBox.get('$tmdbId');
    if (json != null) {
      return WatchHistory.fromJson(
        Map<String, dynamic>.from(_parseJson(json)),
      );
    }
    return null;
  }

  Future<void> deleteHistory(int tmdbId) async {
    if (!_initialized) await init();
    await _historyBox.delete('$tmdbId');
  }

  Future<void> clearAllHistory() async {
    if (!_initialized) await init();
    await _historyBox.clear();
  }

  Map<String, dynamic> _parseJson(String jsonString) =>
      Map<String, dynamic>.from(jsonDecode(jsonString));

  String _toJsonString(Map<String, dynamic> json) => jsonEncode(json);
}
