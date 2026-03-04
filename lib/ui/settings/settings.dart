import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namizo/providers/homeproviders.dart';
import 'package:namizo/providers/serviceproviders.dart';
import 'package:namizo/providers/settingsproviders.dart';
import 'package:namizo/providers/watchhistoryprovider.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/theme/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  bool get _supportsBackgroundTasks => true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationsEnabled = ref.watch(animationsEnabledProvider);
    final episodeCheckEnabled = ref.watch(episodeCheckEnabledProvider);
    final aniListViewerAsync = ref.watch(aniListViewerProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: NamizoTheme.netflixBlack,
        title: const Text(
          'Settings',
          style: NamizoTheme.pageHeaderStyle,
        ),
        leading: IconButton(
          icon: const PhosphorIcon(
            PhosphorIconsRegular.caretLeft,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final uri = Uri.parse('https://keepandroidopen.org/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Ink(
                  decoration: BoxDecoration(
                    color: NamizoTheme.netflixRed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: NamizoTheme.netflixRed.withValues(alpha: 0.35),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: const Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.warning,
                        color: NamizoTheme.netflixRed,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keep Android Open',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Learn more about the developer verification issue',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      PhosphorIcon(
                        PhosphorIconsRegular.arrowSquareOut,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          _buildSectionHeader('Account'),
          aniListViewerAsync.when(
            data: (viewer) {
              if (viewer == null) {
                return _buildSettingsTile(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.signIn,
                    color: Colors.white,
                    size: 24,
                  ),
                  title: 'Login AniList',
                  subtitle: 'Connect your AniList account',
                  trailing: const PhosphorIcon(
                    PhosphorIconsRegular.caretRight,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onTap: () async {
                    final result = await context.push<String>('/anilist/login');
                    if (result == 'success') {
                      ref.read(aniListAccountRefreshProvider.notifier).state++;
                    }
                  },
                );
              }

              final username = (viewer['name'] ?? 'Unknown').toString();
              final watchlistCount =
                  ((viewer['statistics'] as Map<String, dynamic>?)?['anime']
                              as Map<String, dynamic>?)?['count']
                          ?.toString() ??
                      'Unavailable';

              return Column(
                children: [
                  _buildSettingsTile(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.userCircle,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: 'AniList Username',
                    subtitle: username,
                    trailing: null,
                  ),
                  _buildSettingsTile(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.bookmarkSimple,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: 'AniList Watchlist',
                    subtitle: '$watchlistCount entries',
                    trailing: null,
                  ),
                  _buildSettingsTile(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.signOut,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: 'Logout AniList',
                    subtitle: 'Disconnect AniList account',
                    trailing: const PhosphorIcon(
                      PhosphorIconsRegular.caretRight,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onTap: () async {
                      await ref.read(aniListServiceProvider).logout();
                      ref.read(aniListAccountRefreshProvider.notifier).state++;
                    },
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          if (_supportsBackgroundTasks) ...[
            _buildSectionHeader('Notifications'),
            _buildSettingsTile(
              icon: const PhosphorIcon(
                PhosphorIconsRegular.bell,
                color: Colors.white,
                size: 24,
              ),
              title: 'New Episode Alerts',
              subtitle: episodeCheckEnabled ? 'Enabled' : 'Disabled',
              trailing: Switch(
                value: episodeCheckEnabled,
                onChanged: (value) {
                  ref.read(episodeCheckEnabledProvider.notifier).setEnabled(value);
                },
                activeThumbColor: NamizoTheme.netflixRed,
              ),
            ),
            if (episodeCheckEnabled) ...[
              _buildSettingsTile(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.calendar,
                  color: Colors.white,
                  size: 24,
                ),
                title: 'Check Frequency',
                subtitle: ref.read(episodeCheckFrequencyProvider.notifier).displayName,
                trailing: const PhosphorIcon(
                  PhosphorIconsRegular.caretRight,
                  color: Colors.white70,
                  size: 18,
                ),
                onTap: () {
                  _showFrequencyDialog(context, ref);
                },
              ),
              _buildSettingsTile(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.arrowsClockwise,
                  color: Colors.white,
                  size: 24,
                ),
                title: 'Check Now',
                subtitle: 'Manually check for new episodes',
                trailing: const PhosphorIcon(
                  PhosphorIconsRegular.caretRight,
                  color: Colors.white70,
                  size: 18,
                ),
                onTap: () async {
                  _showCheckingDialog(context, ref);
                },
              ),
              FutureBuilder<DateTime?>(
                future: EpisodeCheckService.getLastCheckTime(),
                builder: (context, snapshot) {
                  final lastCheck = snapshot.data;
                  final subtitle = lastCheck != null
                      ? 'Last checked: ${DateFormat.yMMMd().add_jm().format(lastCheck)}'
                      : 'Never checked';
                  return _buildSettingsTile(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.clock,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: 'Last Check',
                    subtitle: subtitle,
                    trailing: null,
                  );
                },
              ),
            ],
          ],

          _buildSectionHeader('Data & Storage'),
          _buildSettingsTile(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.clockCounterClockwise,
              color: Colors.white,
              size: 24,
            ),
            title: 'Clear Watch History',
            subtitle: 'Remove all watch history data',
            trailing: const PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              color: Colors.white70,
              size: 18,
            ),
            onTap: () {
              _showClearHistoryDialog(context, ref);
            },
          ),
          _buildSettingsTile(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.database,
              color: Colors.white,
              size: 24,
            ),
            title: 'Clear Cache',
            subtitle: 'Remove cached metadata and artwork',
            trailing: const PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              color: Colors.white70,
              size: 18,
            ),
            onTap: () {
              _showClearCacheDialog(context, ref);
            },
          ),

          _buildSectionHeader('Appearance'),
          _buildSettingsTile(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.moon,
              color: Colors.white,
              size: 24,
            ),
            title: 'Theme',
            subtitle: themeModeDisplayName(currentThemeMode),
            trailing: const PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              color: Colors.white70,
              size: 18,
            ),
            onTap: () => _showThemeModeDialog(context, ref),
          ),
          _buildSettingsTile(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.sparkle,
              color: Colors.white,
              size: 24,
            ),
            title: 'Animations',
            subtitle: animationsEnabled ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: animationsEnabled,
              onChanged: (_) {
                ref.read(animationsEnabledProvider.notifier).toggle();
              },
              activeThumbColor: NamizoTheme.netflixRed,
            ),
          ),

          _buildSectionHeader('About'),
          FutureBuilder<String>(
            future: _getAppVersionLabel(),
            builder: (context, snapshot) {
              return _buildSettingsTile(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.info,
                  color: Colors.white,
                  size: 24,
                ),
                title: 'App Version',
                subtitle: snapshot.data ?? 'Loading...',
                trailing: null,
              );
            },
          ),
          _buildSettingsTile(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.githubLogo,
              color: Colors.white,
              size: 24,
            ),
            title: 'GitHub Repository',
            subtitle: 'View source code',
            trailing: const PhosphorIcon(
              PhosphorIconsRegular.arrowSquareOut,
              color: Colors.white70,
              size: 18,
            ),
            onTap: () async {
              final uri = Uri.parse('https://github.com/NotMugil/namizo');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<String> _getAppVersionLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.buildNumber.isEmpty) {
        return info.version;
      }
      return '${info.version} (${info.buildNumber})';
    } catch (_) {
      return 'Unknown';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: NamizoTheme.sectionHeaderStyle,
      ),
    );
  }

  Widget _buildSettingsTile({
    required Widget icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: SizedBox(width: 28, height: 28, child: Center(child: icon)),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white60, fontSize: 13),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NamizoTheme.netflixDarkGrey,
        title: const Text(
          'Clear Watch History?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove all your watch history data. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              final historyService = ref.read(watchHistoryServiceProvider);
              await historyService.clearAllHistory();
              ref.invalidate(continueWatchingProvider);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Watch history cleared successfully'),
                    backgroundColor: NamizoTheme.netflixRed,
                  ),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: NamizoTheme.netflixRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NamizoTheme.netflixDarkGrey,
        title: const Text(
          'Clear Cache?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove cached metadata and artwork. Data will be fetched again when needed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              final cacheService = ref.read(cacheServiceProvider);
              await cacheService.clearAll();

              ref.invalidate(featuredAnimeProvider);
              ref.invalidate(popularAnimeProvider);
              ref.invalidate(trendingAnimeProvider);
              ref.invalidate(topRatedAnimeProvider);
              ref.invalidate(romanceAnimeProvider);
              ref.invalidate(actionAnimeProvider);
              ref.invalidate(adventureAnimeProvider);
              ref.invalidate(fantasyAnimeProvider);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache cleared successfully'),
                    backgroundColor: NamizoTheme.netflixRed,
                  ),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: NamizoTheme.netflixRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showFrequencyDialog(BuildContext context, WidgetRef ref) {
    final frequencies = [
      {'value': 12, 'label': 'Every 12 hours (Frequent)'},
      {'value': 24, 'label': 'Daily (Recommended)'},
      {'value': 48, 'label': 'Every 2 days (Battery Saver)'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NamizoTheme.netflixDarkGrey,
        title: const Text(
          'Check Frequency',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Choose how often to check for new episodes. More frequent checks use more battery.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            RadioGroup<int>(
              groupValue: ref.read(episodeCheckFrequencyProvider),
              onChanged: (value) {
                if (value == null) return;
                ref.read(episodeCheckFrequencyProvider.notifier).setFrequency(value);
                Navigator.pop(dialogContext);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: frequencies
                    .map(
                      (freq) => RadioListTile<int>(
                        value: freq['value'] as int,
                        activeColor: NamizoTheme.netflixRed,
                        title: Text(
                          freq['label'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, WidgetRef ref) {
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final currentThemeMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NamizoTheme.netflixDarkGrey,
        title: const Text(
          'Theme',
          style: TextStyle(color: Colors.white),
        ),
        content: RadioGroup<ThemeMode>(
          groupValue: currentThemeMode,
          onChanged: (value) {
            if (value == null) return;
            themeModeNotifier.setThemeMode(value);
            Navigator.pop(dialogContext);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                activeColor: NamizoTheme.netflixRed,
                title: Text(
                  'Follow system',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                activeColor: NamizoTheme.netflixRed,
                title: Text(
                  'Dark',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckingDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NamizoTheme.netflixDarkGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: NamizoTheme.netflixRed),
            const SizedBox(height: 20),
            const Text(
              'Checking for new episodes...',
              style: TextStyle(color: Colors.white),
            ),
            FutureBuilder<int>(
              future: EpisodeCheckService.checkNow(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      final count = snapshot.data ?? 0;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            count > 0
                                ? '🎉 Found $count new episode${count > 1 ? 's' : ''}!'
                                : 'No new episodes found',
                          ),
                          backgroundColor: NamizoTheme.netflixRed,
                        ),
                      );
                    }
                  });
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
