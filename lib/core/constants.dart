// Image size hints
const String posterSize = 'w500';
const String backdropSize = 'original';

// Common timeout values
const Duration shortTimeout = Duration(seconds: 8);
const Duration standardTimeout = Duration(seconds: 15);
const Duration extendedTimeout = Duration(seconds: 20);

// Video Quality Priority
const List<String> qualityPriority = [
  '2160p',
  '1440p',
  '1080p',
  '720p',
  '480p',
  '360p',
  'auto',
];

// Shared preferences keys
const String playbackSpeedKey = 'playback_speed';
const String videoQualityKey = 'video_quality';
const String subtitlesEnabledKey = 'subtitles_enabled';
const String animationsEnabledKey = 'animations_enabled';
const String animeSubDubKey = 'anime_subdub';
const String showAnimeKey = 'showAnime';
const String anilistAccessTokenKey = 'anilist_access_token';
const String anilistSessionCookieKey = 'anilist_session_cookie';
const String lastEpisodeCheckKey = 'last_episode_check';
const String episodeCheckFrequencyKey = 'episode_check_frequency';
const String episodeCheckEnabledKey = 'episode_check_enabled';
const String themeModeKey = 'theme_mode';
