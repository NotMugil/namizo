import 'package:namizo/core/config.dart';

final class TmdbGenres {
  const TmdbGenres._();

  static const int romance = 18;
  static const int action = 10759;
  static const int adventure = 12;
  static const int fantasy = 10765;

  static const Map<int, String> labels = <int, String>{
    16: 'Animation',
    28: 'Action',
    adventure: 'Adventure',
    14: 'Fantasy',
    35: 'Comedy',
    romance: 'Drama',
    9648: 'Mystery',
    878: 'Sci-Fi',
    action: 'Action & Adventure',
    fantasy: 'Fantasy',
  };
}

const String posterSize = 'w500';
const String backdropSize = 'original';

// ── Common timeout values ───────────────────────────────────────────────
const Duration shortTimeout = Duration(seconds: 8);
const Duration standardTimeout = Duration(seconds: 15);
const Duration extendedTimeout = Duration(seconds: 20);

// ── Cache durations ─────────────────────────────────────────────────────
const String cacheBoxName = AppConfigurations.tvdbCacheBoxName;
const Duration shortCache = Duration(minutes: 15);
const Duration mediumCache = Duration(hours: 1);
const Duration longCache = Duration(hours: 24);
const Duration extraLongCache = Duration(days: 7);

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
const String aniListAutoSyncKey = 'anilist_auto_sync';
const String lastEpisodeCheckKey = 'last_episode_check';
const String episodeCheckFrequencyKey = 'episode_check_frequency';
const String episodeCheckEnabledKey = 'episode_check_enabled';
const String themeModeKey = 'theme_mode';
const String easterEggHomeLogoKey = 'easter_egg_home_logo_enabled';
const String hideAdultContentKey = 'hide_adult_content';
const String scheduleTrackedOnlyKey = 'schedule_tracked_only';
const String scheduleTrackedHintDismissedKey =
    'schedule_tracked_hint_dismissed';
const String homeFeedOrderKey = 'home_feed_order';
const String updateReminderDisabledKey = 'update_reminder_disabled';
