class AppConfigurations {
  const AppConfigurations._();

  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';
  static const String tvdbBaseUrl = 'https://api4.thetvdb.com/v4';
  static const String tvdbMappingUrl =
      'https://raw.githubusercontent.com/varoOP/shinkro-mapping/main/tvdb-mal.yaml';
  static const String anilistGraphQlBaseUrl = 'https://graphql.anilist.co';
    static const String anilistOauthAuthorizeUrl =
            'https://anilist.co/api/v2/oauth/authorize';
    static const String anilistOauthClientId =
            String.fromEnvironment('ANILIST_CLIENT_ID', defaultValue: '');
    static const String anilistOauthRedirectUri = String.fromEnvironment(
        'ANILIST_REDIRECT_URI',
      defaultValue: '',
    );

  static const String defaultAppUserAgent =
      'namizo/1.0 (compatible; +https://example.com)';
  static const String mobileChromeUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const String tmdbCacheBoxName = 'tmdb_cache';
  static const String watchlistBoxName = 'watchlist';
  static const String watchHistoryBoxName = 'watch_history';
  static const String newEpisodesBoxName = 'new_episodes';
}
