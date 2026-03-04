class UserConfig {
  const UserConfig._();

  // Optional TVDB credentials for richer metadata enrichment.
  // Keep empty to disable TVDB enrichment.
  static const String tvdbApiKey = '57a0987c-f38d-45b3-acf0-f84ffee71196';
  static const String tvdbPin = '';

  static const bool defaultEpisodeCheckEnabled = true;
  static const int defaultEpisodeCheckFrequencyHours = 24;
  static const bool defaultShowAnime = true;
  static const bool defaultSubtitlesEnabled = false;
  static const bool defaultAnimationsEnabled = true;
  static const double defaultPlaybackSpeed = 1.0;
  static const String defaultVideoQuality = 'auto';
  static const String defaultAnimeSubDubPreference = 'sub';
}
