import 'dart:async';
import 'dart:ui';
import 'package:aimi_lib/aimi_lib.dart' as aimi;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:namizo/core/config.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/core/defaults.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/new_episode.dart';
import '../models/watchlist_item.dart';

/// Service for checking new episodes of watchlist TV shows.
/// Uses WorkManager for battery-efficient background tasks (Android/iOS only).
class EpisodeCheckService {
  static const String _taskName = 'episodeCheckTask';
  static const String _boxName = AppConfigurations.newEpisodesBoxName;
  static const String _lastCheckKey = lastEpisodeCheckKey;
  static const String _frequencyKey = episodeCheckFrequencyKey;
  static const String _enabledKey = episodeCheckEnabledKey;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final aimi.Kuroiru _kuroiru = aimi.Kuroiru();

  static bool get _supportsBackgroundTasks => true;

  static Future<void> init() async {
    await _initNotifications();

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<NewEpisode>(_boxName);
    }

    if (_supportsBackgroundTasks) {
      await Workmanager().initialize(
        episodeCheckCallbackDispatcher,
        isInDebugMode: false,
      );

      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(_enabledKey) ?? UserConfig.defaultEpisodeCheckEnabled;
      if (enabled) {
        await registerPeriodicTask();
      }
    }
  }

  static Future<void> _initNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Notification initialization failed — app still works without notifications.
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Navigation on tap is handled by the app when it resumes.
  }

  static Future<void> registerPeriodicTask() async {
    if (!_supportsBackgroundTasks) return;

    final prefs = await SharedPreferences.getInstance();
    final frequencyHours =
        prefs.getInt(_frequencyKey) ??
        UserConfig.defaultEpisodeCheckFrequencyHours;

    await Workmanager().cancelByUniqueName(_taskName);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: Duration(hours: frequencyHours),
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 10),
    );
  }

  static Future<void> cancelPeriodicTask() async {
    if (!_supportsBackgroundTasks) return;
    await Workmanager().cancelByUniqueName(_taskName);
  }

  static Future<int> getFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_frequencyKey) ??
        UserConfig.defaultEpisodeCheckFrequencyHours;
  }

  static Future<void> setFrequency(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_frequencyKey, hours);

    final enabled =
        prefs.getBool(_enabledKey) ?? UserConfig.defaultEpisodeCheckEnabled;
    if (enabled) {
      await registerPeriodicTask();
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? UserConfig.defaultEpisodeCheckEnabled;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      await registerPeriodicTask();
    } else {
      await cancelPeriodicTask();
    }
  }

  static Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastCheckKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  static List<NewEpisode> getNewEpisodes() {
    if (!Hive.isBoxOpen(_boxName)) return [];
    final box = Hive.box<NewEpisode>(_boxName);
    return box.values.toList()
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
  }

  static int getUnreadCount() {
    if (!Hive.isBoxOpen(_boxName)) return 0;
    final box = Hive.box<NewEpisode>(_boxName);
    return box.values.where((e) => !e.isRead).length;
  }

  static Future<void> markAsRead(String key) async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<NewEpisode>(_boxName);
    final episode = box.get(key);
    if (episode != null) {
      await box.put(key, episode.copyWith(isRead: true));
    }
  }

  static Future<void> markAllAsRead() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<NewEpisode>(_boxName);
    for (final key in box.keys) {
      final episode = box.get(key);
      if (episode != null && !episode.isRead) {
        await box.put(key, episode.copyWith(isRead: true));
      }
    }
  }

  static Future<void> clearAll() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<NewEpisode>(_boxName);
    await box.clear();
  }

  static Future<int> checkNow() async {
    return _performEpisodeCheck();
  }

  static Future<void> initNotificationsForBackground() async {
    await _initNotifications();
  }

  static Future<int> performEpisodeCheckForBackground() async {
    return _performEpisodeCheck();
  }

  static Future<int> _performEpisodeCheck() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return 0;

      if (!Hive.isBoxOpen(AppConfigurations.watchlistBoxName)) {
        await Hive.openBox<WatchlistItem>(AppConfigurations.watchlistBoxName);
      }
      final watchlistBox =
          Hive.box<WatchlistItem>(AppConfigurations.watchlistBoxName);
      final tvShows =
          watchlistBox.values.where((item) => item.mediaType == 'tv').toList();

      if (tvShows.isEmpty) return 0;

      final prefs = await SharedPreferences.getInstance();
      final lastCheckTimestamp = prefs.getInt(_lastCheckKey);
      final lastCheck = lastCheckTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp)
          : DateTime.now().subtract(const Duration(days: 7));

      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<NewEpisode>(_boxName);
      }
      final episodesBox = Hive.box<NewEpisode>(_boxName);

      var newEpisodesFound = 0;
      final newEpisodesList = <NewEpisode>[];

      for (final show in tvShows) {
        try {
          await Future.delayed(const Duration(milliseconds: 500));

          final episodes = await _checkShowForNewEpisodes(
            show.id,
            show.title,
            show.posterPath,
            lastCheck,
          );

          for (final episode in episodes) {
            if (!episodesBox.containsKey(episode.key)) {
              await episodesBox.put(episode.key, episode);
              newEpisodesList.add(episode);
              newEpisodesFound++;
            }
          }
        } catch (_) {
          // Skip shows that fail to fetch — continue with others.
        }
      }

      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      if (newEpisodesFound > 0) {
        await _showNewEpisodeNotification(newEpisodesList);
      }

      return newEpisodesFound;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<NewEpisode>> _checkShowForNewEpisodes(
    int showId,
    String showName,
    String? posterPath,
    DateTime since,
  ) async {
    final newEpisodes = <NewEpisode>[];

    try {
      final details = await _kuroiru.getDetails('$showId');
      final latestEpisode = details.lastEpisode ?? details.episodes ?? 0;
      if (latestEpisode <= 0) return [];

      final status = (details.status ?? '').toLowerCase();
      if (status.contains('not yet') || status.contains('upcoming')) {
        return [];
      }

      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<NewEpisode>(_boxName);
      }
      final episodesBox = Hive.box<NewEpisode>(_boxName);

      var highestKnownEpisode = 0;
      for (final existing in episodesBox.values) {
        if (existing.showId == showId &&
            existing.episodeNumber > highestKnownEpisode) {
          highestKnownEpisode = existing.episodeNumber;
        }
      }

      if (latestEpisode <= highestKnownEpisode) return [];

      final startEpisode =
          highestKnownEpisode == 0 ? latestEpisode : highestKnownEpisode + 1;

      final scheduledAt = details.schedule != null
          ? DateTime.fromMillisecondsSinceEpoch(details.schedule! * 1000)
          : DateTime.now();
      final airDate = scheduledAt.isAfter(DateTime.now())
          ? DateTime.now()
          : scheduledAt;

      for (var ep = startEpisode; ep <= latestEpisode; ep++) {
        newEpisodes.add(
          NewEpisode(
            showId: showId,
            showName: showName,
            seasonNumber: 1,
            episodeNumber: ep,
            episodeName: 'Episode $ep',
            posterPath: posterPath,
            airDate: airDate.isAfter(since) ? airDate : DateTime.now(),
            detectedAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {
      // Silently skip — show will be re-checked next cycle.
    }

    return newEpisodes;
  }

  static Future<void> _showNewEpisodeNotification(
    List<NewEpisode> episodes,
  ) async {
    if (episodes.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      AppConfigurations.newEpisodesBoxName,
      'New Episodes',
      channelDescription:
          'Notifications for new episodes of shows in your watchlist',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFE50914),
      groupKey: 'new_episodes_group',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    if (episodes.length == 1) {
      final episode = episodes.first;
      await _notifications.show(
        episode.hashCode,
        'New Episode Available!',
        '${episode.showName} S${episode.seasonNumber}E${episode.episodeNumber}: ${episode.episodeName}',
        details,
        payload: '${episode.showId}',
      );
    } else {
      final showNames = episodes.map((e) => e.showName).toSet().toList();
      final title = showNames.length == 1
          ? showNames.first
          : '${episodes.length} New Episodes';
      final body = showNames.length == 1
          ? '${episodes.length} new episodes available'
          : 'New episodes from ${showNames.take(3).join(", ")}${showNames.length > 3 ? " and more" : ""}';

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    }
  }
}

/// WorkManager callback dispatcher (must be a top-level function).
@pragma('vm:entry-point')
void episodeCheckCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(WatchlistItemAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(NewEpisodeAdapter());
      }

      await EpisodeCheckService.initNotificationsForBackground();
      await EpisodeCheckService.performEpisodeCheckForBackground();
      return true;
    } catch (_) {
      return false;
    }
  });
}
