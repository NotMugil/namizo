class UserConfig {
  const UserConfig._();

  // Optional TVDB credentials for richer metadata enrichment.
  // Set via --dart-define=TVDB_API_KEY=... and --dart-define=TVDB_PIN=...
  // Keep empty to disable TVDB enrichment.
  static const String tvdbApiKey = String.fromEnvironment(
    'TVDB_API_KEY',
    defaultValue: '',
  );
  static const String tvdbPin = String.fromEnvironment(
    'TVDB_PIN',
    defaultValue: '',
  );

  static const bool defaultEpisodeCheckEnabled = true;
  static const int defaultEpisodeCheckFrequencyHours = 6;
  static const bool defaultShowAnime = true;
  static const bool defaultSubtitlesEnabled = false;
  static const bool defaultAnimationsEnabled = true;
  static const double defaultPlaybackSpeed = 1.0;
  static const String defaultVideoQuality = 'auto';
  static const String defaultAnimeSubDubPreference = 'sub';
  static const String defaultThemeMode = 'system';
  static const bool defaultAniListAutoSync = true;
  static const bool defaultHideSpoilers = false;
  static const List<String> defaultHomeFeedOrder = [
    'yourList',
    'planning',
    'continueWatching',
    'popular',
    'trending',
    'topRated',
    'romance',
    'action',
    'adventure',
    'fantasy',
  ];
}
