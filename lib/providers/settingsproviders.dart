import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/core/user_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/episodes.dart';

// Playback Speed Provider
final playbackSpeedProvider = StateNotifierProvider<PlaybackSpeedNotifier, double>((ref) {
  return PlaybackSpeedNotifier();
});

class PlaybackSpeedNotifier extends StateNotifier<double> {
  PlaybackSpeedNotifier() : super(UserConfig.defaultPlaybackSpeed) {
    _loadSpeed();
  }

  Future<void> _loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(playbackSpeedKey) ?? UserConfig.defaultPlaybackSpeed;
  }

  Future<void> setSpeed(double speed) async {
    state = speed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(playbackSpeedKey, speed);
  }
}

// Video Quality Provider
final videoQualityProvider = StateNotifierProvider<VideoQualityNotifier, String>((ref) {
  return VideoQualityNotifier();
});

class VideoQualityNotifier extends StateNotifier<String> {
  VideoQualityNotifier() : super(UserConfig.defaultVideoQuality) {
    _loadQuality();
  }

  Future<void> _loadQuality() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(videoQualityKey) ?? UserConfig.defaultVideoQuality;
  }

  Future<void> setQuality(String quality) async {
    state = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(videoQualityKey, quality);
  }

  String get displayName {
    switch (state) {
      case 'auto':
        return 'Auto (Best Available)';
      case '2160p':
        return '4K (2160p)';
      case '1080p':
        return 'Full HD (1080p)';
      case '720p':
        return 'HD (720p)';
      case '480p':
        return 'SD (480p)';
      default:
        return 'Auto';
    }
  }
}

// Subtitle Enabled Provider
final subtitlesEnabledProvider = StateNotifierProvider<SubtitlesEnabledNotifier, bool>((ref) {
  return SubtitlesEnabledNotifier();
});

class SubtitlesEnabledNotifier extends StateNotifier<bool> {
  SubtitlesEnabledNotifier() : super(UserConfig.defaultSubtitlesEnabled) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(subtitlesEnabledKey) ?? UserConfig.defaultSubtitlesEnabled;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(subtitlesEnabledKey, state);
  }
}

// Animations Enabled Provider
final animationsEnabledProvider = StateNotifierProvider<AnimationsEnabledNotifier, bool>((ref) {
  return AnimationsEnabledNotifier();
});

class AnimationsEnabledNotifier extends StateNotifier<bool> {
  AnimationsEnabledNotifier() : super(UserConfig.defaultAnimationsEnabled) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(animationsEnabledKey) ?? UserConfig.defaultAnimationsEnabled;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(animationsEnabledKey, state);
  }
}

// Anime Sub/Dub Preference Provider
final animeSubDubProvider = StateNotifierProvider<AnimeSubDubNotifier, String>((ref) {
  return AnimeSubDubNotifier();
});

class AnimeSubDubNotifier extends StateNotifier<String> {
  AnimeSubDubNotifier() : super(UserConfig.defaultAnimeSubDubPreference) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(animeSubDubKey) ?? UserConfig.defaultAnimeSubDubPreference;
  }

  Future<void> setPreference(String preference) async {
    if (preference != 'sub' && preference != 'dub') return;
    state = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(animeSubDubKey, preference);
  }

  String get displayName {
    return state == 'sub' ? 'Subtitled (Sub)' : 'Dubbed (Dub)';
  }
}

// Episode Check Enabled Provider
final episodeCheckEnabledProvider = StateNotifierProvider<EpisodeCheckEnabledNotifier, bool>((ref) {
  return EpisodeCheckEnabledNotifier();
});

class EpisodeCheckEnabledNotifier extends StateNotifier<bool> {
  EpisodeCheckEnabledNotifier() : super(UserConfig.defaultEpisodeCheckEnabled) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await EpisodeCheckService.isEnabled();
  }

  Future<void> toggle() async {
    state = !state;
    await EpisodeCheckService.setEnabled(state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await EpisodeCheckService.setEnabled(enabled);
  }
}

// Episode Check Frequency Provider
final episodeCheckFrequencyProvider = StateNotifierProvider<EpisodeCheckFrequencyNotifier, int>((ref) {
  return EpisodeCheckFrequencyNotifier();
});

class EpisodeCheckFrequencyNotifier extends StateNotifier<int> {
  EpisodeCheckFrequencyNotifier() : super(UserConfig.defaultEpisodeCheckFrequencyHours) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await EpisodeCheckService.getFrequency();
  }

  Future<void> setFrequency(int hours) async {
    state = hours;
    await EpisodeCheckService.setFrequency(hours);
  }

  String get displayName {
    switch (state) {
      case 12:
        return 'Every 12 hours';
      case 24:
        return 'Daily';
      case 48:
        return 'Every 2 days';
      default:
        return 'Every $state hours';
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

String themeModeDisplayName(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.system:
      return 'Follow system';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.light:
      return 'Follow system';
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final rawMode =
        prefs.getString(themeModeKey) ?? UserConfig.defaultThemeMode;
    state = _fromStorageValue(rawMode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, _toStorageValue(mode));
  }

  ThemeMode _fromStorageValue(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.system;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _toStorageValue(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'system';
      case ThemeMode.system:
        return 'system';
    }
  }
}
