import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:namizo/providers/home.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/providers/watch_history.dart';
import 'package:namizo/providers/watchlist.dart';
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
    final lastCheckAsync = ref.watch(lastEpisodeCheckTimeProvider);
    final aniListAutoSync = ref.watch(aniListAutoSyncProvider);
    final easterEggEnabled = ref.watch(easterEggHomeLogoProvider);
    final hideAdultContent = ref.watch(hideAdultContentProvider);
    final scheduleTrackedOnly = ref.watch(scheduleTrackedOnlyProvider);
    final homeFeedOrder = ref.watch(homeFeedOrderProvider);
    void handleBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          handleBack();
        }
      },
      child: Scaffold(
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
            onPressed: handleBack,
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
                    final result = await context.push<bool>('/anilist-login');
                    if (result == true) {
                      ref.read(aniListAccountRefreshProvider.notifier).state++;
                    }
                  },
                );
              }

              final username = (viewer['name'] ?? 'Unknown').toString();

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
                  _buildSettingsTile(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.cloudArrowUp,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: 'Auto AniList Sync',
                    subtitle: aniListAutoSync
                        ? 'Automatically sync add/remove/progress'
                        : 'Manual sync only',
                    trailing: Switch(
                      value: aniListAutoSync,
                      onChanged: (value) {
                        ref
                            .read(aniListAutoSyncProvider.notifier)
                            .setEnabled(value);
                      },
                      activeThumbColor: NamizoTheme.netflixRed,
                    ),
                  ),
                  _buildSettingsTile(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.arrowsClockwise,
                      color: Colors.white,
                      size: 24,
                    ),
                    title: 'Sync Local Watchlist',
                    subtitle: 'Push local watchlist entries to AniList planning',
                    trailing: const PhosphorIcon(
                      PhosphorIconsRegular.caretRight,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onTap: () => _syncLocalWatchlistToAniList(context, ref),
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
              lastCheckAsync.when(
                data: (lastCheck) {
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
                loading: () => _buildSettingsTile(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.clock,
                    color: Colors.white,
                    size: 24,
                  ),
                  title: 'Last Check',
                  subtitle: 'Loading...',
                  trailing: null,
                ),
                error: (_, __) => _buildSettingsTile(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.clock,
                    color: Colors.white,
                    size: 24,
                  ),
                  title: 'Last Check',
                  subtitle: 'Unavailable',
                  trailing: null,
                ),
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
              PhosphorIconsRegular.listNumbers,
              color: Colors.white,
              size: 24,
            ),
            title: 'Home Feed Order',
            subtitle:
                '${homeFeedOrder.length} rows • Tap to reorder sections',
            trailing: const PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              color: Colors.white70,
              size: 18,
            ),
            onTap: () => _showHomeFeedOrderSheet(context, ref),
          ),
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
          _buildSettingsTile(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.eyeSlash,
              color: Colors.white,
              size: 24,
            ),
            title: 'Hide Adult Content',
            subtitle: hideAdultContent ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: hideAdultContent,
              onChanged: (value) {
                ref.read(hideAdultContentProvider.notifier).setEnabled(value);
              },
              activeThumbColor: NamizoTheme.netflixRed,
            ),
          ),
          _buildSettingsTile(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.calendarCheck,
              color: Colors.white,
              size: 24,
            ),
            title: 'Tracked Only in Schedule',
            subtitle: scheduleTrackedOnly ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: scheduleTrackedOnly,
              onChanged: (value) {
                ref.read(scheduleTrackedOnlyProvider.notifier).setEnabled(value);
              },
              activeThumbColor: NamizoTheme.netflixRed,
            ),
          ),
          if (easterEggEnabled)
            _buildSettingsTile(
              icon: const PhosphorIcon(
                PhosphorIconsRegular.arrowCounterClockwise,
                color: Colors.white,
                size: 24,
              ),
              title: 'Revert Home Logo',
              subtitle: 'Switch back to Namizo title text',
              trailing: const PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                color: Colors.white70,
                size: 18,
              ),
              onTap: () async {
                await ref.read(easterEggHomeLogoProvider.notifier).setEnabled(false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Home logo reverted to Namizo'),
                    backgroundColor: NamizoTheme.netflixRed,
                  ),
                );
              },
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
                onTap: () async {
                  final currentCount =
                      ref.read(easterEggVersionTapCountProvider) + 1;
                  ref.read(easterEggVersionTapCountProvider.notifier).state =
                      currentCount;

                  if (!easterEggEnabled && currentCount >= 6) {
                    await ref
                        .read(easterEggHomeLogoProvider.notifier)
                        .setEnabled(true);
                    ref.read(easterEggVersionTapCountProvider.notifier).state =
                        0;
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 Easter egg enabled!'),
                        backgroundColor: NamizoTheme.netflixRed,
                      ),
                    );
                  }
                },
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
      ),
    );
  }

  Future<void> _showHomeFeedOrderSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentOrder = ref.read(homeFeedOrderProvider);
    final editable = List<String>.from(currentOrder);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        'Reorder Home Feed',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'Drag rows to change their order on the Home page.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: editable.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = editable.removeAt(oldIndex);
                          editable.insert(newIndex, item);
                          setModalState(() {});
                          await ref
                              .read(homeFeedOrderProvider.notifier)
                              .setOrder(editable);
                        },
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                        itemBuilder: (context, index) {
                          final key = editable[index];
                          return Container(
                            key: ValueKey('home_feed_$key'),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                _homeFeedLabel(key),
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: const Icon(
                                Icons.drag_handle,
                                color: Colors.white60,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _homeFeedLabel(String key) {
    switch (key) {
      case 'popular':
        return 'All Time Popular';
      case 'trending':
        return 'Trending Now';
      case 'topRated':
        return 'Top Rated Anime';
      case 'romance':
        return 'Romance';
      case 'action':
        return 'Action';
      case 'adventure':
        return 'Adventure';
      case 'fantasy':
        return 'Fantasy';
      default:
        return key;
    }
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
                      ref
                          .read(episodeCheckLastCheckRefreshProvider.notifier)
                          .state++;
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

  Future<void> _syncLocalWatchlistToAniList(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final watchlistService = ref.read(watchlistServiceProvider);
    final localItems = watchlistService.getAllItems();
    if (localItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No local watchlist entries to sync'),
          backgroundColor: NamizoTheme.netflixRed,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        backgroundColor: NamizoTheme.netflixDarkGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: NamizoTheme.netflixRed),
            SizedBox(height: 16),
            Text(
              'Syncing local watchlist to AniList...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );

    final result = await ref
        .read(aniListServiceProvider)
        .syncPlanningForMalIds(localItems.map((item) => item.id));

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ref.read(aniListAccountRefreshProvider.notifier).state++;

    final message = result.failed > 0
        ? 'Synced ${result.synced}/${result.attempted} entries to AniList'
        : 'Synced ${result.synced} entries to AniList';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NamizoTheme.netflixRed,
      ),
    );
  }
}
