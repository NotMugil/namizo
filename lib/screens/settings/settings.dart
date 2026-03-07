import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/providers/home.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/providers/update.dart';
import 'package:namizo/providers/watch_history.dart';
import 'package:namizo/providers/watchlist.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/widgets/update_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  bool get _supportsBackgroundTasks => true;
  static const Set<String> _aniListOnlyFeedKeys = {'planning'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationsEnabled = ref.watch(animationsEnabledProvider);
    final episodeCheckEnabled = ref.watch(episodeCheckEnabledProvider);
    final aniListViewerAsync = ref.watch(aniListViewerProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final aniListAutoSync = ref.watch(aniListAutoSyncProvider);
    final easterEggEnabled = ref.watch(easterEggHomeLogoProvider);
    final hideAdultContent = ref.watch(hideAdultContentProvider);
    final scheduleTrackedOnly = ref.watch(scheduleTrackedOnlyProvider);
    final homeFeedOrder = ref.watch(homeFeedOrderProvider);
    final hasAniListAccount = aniListViewerAsync.valueOrNull != null;
    final reorderableFeedOrder = _filterReorderableFeedOrder(
      homeFeedOrder,
      includeAniListRows: hasAniListAccount,
    );
    final updateReminderDisabled = ref.watch(updateReminderDisabledProvider);
    final updateCheckAsync = ref.watch(updateCheckProvider);
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
          backgroundColor: NamizoTheme.background,
          title: const Text('Settings', style: NamizoTheme.pageHeaderStyle),
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
                      color: NamizoTheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: NamizoTheme.primary.withValues(alpha: 0.35),
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
                          color: NamizoTheme.primary,
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

            _buildSectionHeader('Appearance'),
            _buildSettingsTile(
              icon: const PhosphorIcon(
                PhosphorIconsRegular.listNumbers,
                color: Colors.white,
                size: 24,
              ),
              title: 'Home Feed Order',
              subtitle:
                  '${reorderableFeedOrder.length} rows • Tap to reorder sections',
              trailing: const PhosphorIcon(
                PhosphorIconsRegular.caretRight,
                color: Colors.white70,
                size: 18,
              ),
              onTap: () => _showHomeFeedOrderSheet(
                context,
                ref,
                includeAniListRows: hasAniListAccount,
              ),
            ),
            // _buildSettingsTile(
            //   icon: const PhosphorIcon(
            //     PhosphorIconsRegular.moon,
            //     color: Colors.white,
            //     size: 24,
            //   ),
            //   title: 'Theme',
            //   subtitle: themeModeDisplayName(currentThemeMode),
            //   trailing: const PhosphorIcon(
            //     PhosphorIconsRegular.caretRight,
            //     color: Colors.white70,
            //     size: 18,
            //   ),
            //   onTap: () => _showThemeModeDialog(context, ref),
            // ),
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
                activeThumbColor: NamizoTheme.primary,
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
                activeThumbColor: NamizoTheme.primary,
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
                  ref
                      .read(scheduleTrackedOnlyProvider.notifier)
                      .setEnabled(value);
                },
                activeThumbColor: NamizoTheme.primary,
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
                  await ref
                      .read(easterEggHomeLogoProvider.notifier)
                      .setEnabled(false);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Home logo reverted to Namizo'),
                      backgroundColor: NamizoTheme.primary,
                    ),
                  );
                },
              ),

            if (_supportsBackgroundTasks) ...[
              _buildSectionHeader('Alert Preferences'),
              _buildSettingsTile(
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  color: Colors.white,
                  size: 24,
                ),
                title: 'Episode Notifications',
                subtitle: episodeCheckEnabled ? 'Enabled' : 'Disabled',
                trailing: Switch(
                  value: episodeCheckEnabled,
                  onChanged: (value) {
                    ref
                        .read(episodeCheckEnabledProvider.notifier)
                        .setEnabled(value);
                  },
                  activeThumbColor: NamizoTheme.primary,
                ),
              ),
              _buildSettingsTile(
                icon: PhosphorIcon(
                  updateReminderDisabled
                      ? PhosphorIconsRegular.bellSlash
                      : PhosphorIconsRegular.bell,
                  color: Colors.white,
                  size: 24,
                ),
                title: 'Update Notifications',
                subtitle: 'Notify on launch when a new version is available',
                trailing: Switch(
                  value: !updateReminderDisabled,
                  onChanged: (value) {
                    ref
                        .read(updateReminderDisabledProvider.notifier)
                        .setDisabled(!value);
                  },
                  activeThumbColor: NamizoTheme.primary,
                ),
                onTap: () {
                  ref
                      .read(updateReminderDisabledProvider.notifier)
                      .setDisabled(!updateReminderDisabled);
                },
              ),
            ],

            // _buildSectionHeader('Checks'),
            // if (_supportsBackgroundTasks)
            //   _buildSettingsTile(
            //     icon: const PhosphorIcon(
            //       PhosphorIconsRegular.arrowsClockwise,
            //       color: Colors.white,
            //       size: 24,
            //     ),
            //     title: 'Check for Notifications',
            //     subtitle: 'Manually check for new episode notifications',
            //     trailing: const PhosphorIcon(
            //       PhosphorIconsRegular.caretRight,
            //       color: Colors.white70,
            //       size: 18,
            //     ),
            //     onTap: () async {
            //       _showCheckingDialog(context, ref);
            //     },
            //   ),
            // updateCheckAsync.when(
            //   data: (info) => _buildSettingsTile(
            //     icon: PhosphorIcon(
            //       info != null && info.isUpdateAvailable
            //           ? PhosphorIconsFill.arrowCircleUp
            //           : PhosphorIconsRegular.arrowCircleUp,
            //       color: info != null && info.isUpdateAvailable
            //           ? NamizoTheme.primary
            //           : Colors.white,
            //       size: 24,
            //     ),
            //     title: 'Check for Updates',
            //     subtitle: info == null
            //         ? 'Could not check for updates'
            //         : info.isUpdateAvailable
            //         ? 'Update available: v${info.latestVersion}'
            //         : 'Up to date',
            //     trailing: const PhosphorIcon(
            //       PhosphorIconsRegular.arrowCounterClockwise,
            //       color: Colors.white70,
            //       size: 18,
            //     ),
            //     onTap: () {
            //       ref.read(updateCheckRefreshProvider.notifier).state++;
            //       if (info != null && info.isUpdateAvailable) {
            //         showDialog(
            //           context: context,
            //           builder: (_) => UpdateDialog(update: info),
            //         );
            //       } else {
            //         ScaffoldMessenger.of(context).showSnackBar(
            //           const SnackBar(
            //             content: Text('Checking for updates...'),
            //             duration: Duration(seconds: 1),
            //           ),
            //         );
            //       }
            //     },
            //   ),
            //   loading: () => _buildSettingsTile(
            //     icon: const SizedBox(
            //       width: 24,
            //       height: 24,
            //       child: CircularProgressIndicator(strokeWidth: 2),
            //     ),
            //     title: 'Check for Updates',
            //     subtitle: 'Checking...',
            //     trailing: null,
            //     onTap: null,
            //   ),
            //   error: (_, __) => _buildSettingsTile(
            //     icon: const PhosphorIcon(
            //       PhosphorIconsRegular.arrowCircleUp,
            //       color: Colors.white,
            //       size: 24,
            //     ),
            //     title: 'Check for Updates',
            //     subtitle: 'Tap to retry',
            //     trailing: const PhosphorIcon(
            //       PhosphorIconsRegular.arrowCounterClockwise,
            //       color: Colors.white70,
            //       size: 18,
            //     ),
            //     onTap: () {
            //       ref.read(updateCheckRefreshProvider.notifier).state++;
            //     },
            //   ),
            // ),
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
                        ref
                            .read(aniListAccountRefreshProvider.notifier)
                            .state++;
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
                        activeThumbColor: NamizoTheme.primary,
                      ),
                    ),
                    _buildSettingsTile(
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.arrowsClockwise,
                        color: Colors.white,
                        size: 24,
                      ),
                      title: 'Sync Local Watchlist',
                      subtitle:
                          'Push local watchlist entries to AniList planning',
                      trailing: const PhosphorIcon(
                        PhosphorIconsRegular.caretRight,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onTap: () => _syncLocalWatchlistToAniList(context, ref),
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
                        ref
                            .read(aniListAccountRefreshProvider.notifier)
                            .state++;
                      },
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
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

            _buildSectionHeader('App Info'),
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
                      ref
                              .read(easterEggVersionTapCountProvider.notifier)
                              .state =
                          0;
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Easter egg enabled!'),
                          backgroundColor: NamizoTheme.primary,
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
    WidgetRef ref, {
    required bool includeAniListRows,
  }) async {
    final currentOrder = ref.read(homeFeedOrderProvider);
    final editable = _filterReorderableFeedOrder(
      currentOrder,
      includeAniListRows: includeAniListRows,
    );

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
                    if (!includeAniListRows)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'Planning row appears after login.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
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
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('home_feed_$key'),
                            index: index,
                            child: Container(
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

  List<String> _filterReorderableFeedOrder(
    List<String> order, {
    required bool includeAniListRows,
  }) {
    if (includeAniListRows) return List<String>.from(order);
    return order
        .where((key) => !_aniListOnlyFeedKeys.contains(key))
        .toList(growable: false);
  }

  String _homeFeedLabel(String key) {
    switch (key) {
      case 'yourList':
        return 'Your List';
      case 'planning':
        return 'Planning to Watch';
      case 'continueWatching':
        return 'Continue Watching';
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
      child: Text(title, style: NamizoTheme.sectionHeaderStyle),
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
        backgroundColor: NamizoTheme.surface,
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
                    backgroundColor: NamizoTheme.primary,
                  ),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: NamizoTheme.primary),
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
        backgroundColor: NamizoTheme.surface,
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
                    backgroundColor: NamizoTheme.primary,
                  ),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: NamizoTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, WidgetRef ref) {
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final currentThemeMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NamizoTheme.surface,
        title: const Text('Theme', style: TextStyle(color: Colors.white)),
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
                activeColor: NamizoTheme.primary,
                title: Text(
                  'Follow system',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                activeColor: NamizoTheme.primary,
                title: Text('Dark', style: TextStyle(color: Colors.white)),
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
        backgroundColor: NamizoTheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: NamizoTheme.primary),
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
                          backgroundColor: NamizoTheme.primary,
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
          backgroundColor: NamizoTheme.primary,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        backgroundColor: NamizoTheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: NamizoTheme.primary),
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
      SnackBar(content: Text(message), backgroundColor: NamizoTheme.primary),
    );
  }
}
