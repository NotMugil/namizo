import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nivio/core/theme.dart';
import 'package:nivio/providers/settings_providers.dart';
import 'package:nivio/providers/service_providers.dart';
import 'package:nivio/providers/watch_history_provider.dart';
import 'package:nivio/services/episode_check_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// Settings Screen - All settings are functional and persist via SharedPreferences

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Android supports background tasks
  bool get _supportsBackgroundTasks => true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackSpeed = ref.watch(playbackSpeedProvider);
    final videoQualityNotifier = ref.read(videoQualityProvider.notifier);
    final subtitlesEnabled = ref.watch(subtitlesEnabledProvider);
    final animationsEnabled = ref.watch(animationsEnabledProvider);
    final episodeCheckEnabled = ref.watch(episodeCheckEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: NivioTheme.netflixBlack,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          // Playback Settings
          _buildSectionHeader('Playback'),
          _buildSettingsTile(
            icon: Icons.speed,
            title: 'Default Playback Speed',
            subtitle: '${playbackSpeed}x',
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () {
              _showPlaybackSpeedDialog(context, ref);
            },
          ),
          _buildSettingsTile(
            icon: Icons.high_quality,
            title: 'Preferred Video Quality',
            subtitle: videoQualityNotifier.displayName,
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () {
              _showVideoQualityDialog(context, ref);
            },
          ),
          _buildSettingsTile(
            icon: Icons.subtitles_outlined,
            title: 'Enable Subtitles',
            subtitle: subtitlesEnabled ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: subtitlesEnabled,
              onChanged: (_) {
                ref.read(subtitlesEnabledProvider.notifier).toggle();
              },
              activeColor: NivioTheme.netflixRed,
            ),
          ),
          const Divider(color: NivioTheme.netflixDarkGrey, height: 1),

          // Notifications Section (only show on platforms that support background tasks)
          if (_supportsBackgroundTasks) ...[
            _buildSectionHeader('Notifications'),
            _buildSettingsTile(
              icon: Icons.notifications_outlined,
              title: 'New Episode Alerts',
              subtitle: episodeCheckEnabled ? 'Enabled' : 'Disabled',
              trailing: Switch(
                value: episodeCheckEnabled,
                onChanged: (value) {
                  ref
                      .read(episodeCheckEnabledProvider.notifier)
                      .setEnabled(value);
                },
                activeColor: NivioTheme.netflixRed,
              ),
            ),
            if (episodeCheckEnabled) ...[
              _buildSettingsTile(
                icon: Icons.schedule_outlined,
                title: 'Check Frequency',
                subtitle: ref
                    .read(episodeCheckFrequencyProvider.notifier)
                    .displayName,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                ),
                onTap: () {
                  _showFrequencyDialog(context, ref);
                },
              ),
              _buildSettingsTile(
                icon: Icons.refresh_outlined,
                title: 'Check Now',
                subtitle: 'Manually check for new episodes',
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
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
                    icon: Icons.history_outlined,
                    title: 'Last Check',
                    subtitle: subtitle,
                    trailing: null,
                  );
                },
              ),
            ],
            const Divider(color: NivioTheme.netflixDarkGrey, height: 1),
          ],

          // Data & Storage
          _buildSectionHeader('Data & Storage'),
          _buildSettingsTile(
            icon: Icons.storage_outlined,
            title: 'Clear Watch History',
            subtitle: 'Remove all watch history data',
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () {
              _showClearHistoryDialog(context, ref);
            },
          ),
          const Divider(color: NivioTheme.netflixDarkGrey, height: 1),

          // Appearance
          _buildSectionHeader('Appearance'),
          _buildSettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: 'Dark (Netflix Style)',
            trailing: null,
          ),
          _buildSettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Animations',
            subtitle: animationsEnabled ? 'Enabled' : 'Disabled',
            trailing: Switch(
              value: animationsEnabled,
              onChanged: (_) {
                ref.read(animationsEnabledProvider.notifier).toggle();
              },
              activeColor: NivioTheme.netflixRed,
            ),
          ),
          const Divider(color: NivioTheme.netflixDarkGrey, height: 1),

          // About
          _buildSectionHeader('About'),
          FutureBuilder<String>(
            future: _getAppVersionLabel(),
            builder: (context, snapshot) {
              return _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: snapshot.data ?? 'Loading...',
                trailing: null,
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            subtitle: 'View privacy policy',
            trailing: const Icon(Icons.open_in_new, color: Colors.white70),
            onTap: () async {
              final uri = Uri.parse('https://nivio-app.com/privacy');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'View terms of service',
            trailing: const Icon(Icons.open_in_new, color: Colors.white70),
            onTap: () async {
              final uri = Uri.parse('https://nivio-app.com/terms');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
          const Divider(color: NivioTheme.netflixDarkGrey, height: 1),

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
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.white, size: 28),
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
        backgroundColor: NivioTheme.netflixDarkGrey,
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
              // Use the service to clear history (local + cloud)
              final historyService = ref.read(watchHistoryServiceProvider);
              await historyService.clearAllHistory();

              // Invalidate the provider to refresh UI
              ref.invalidate(continueWatchingProvider);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Watch history cleared successfully'),
                    backgroundColor: NivioTheme.netflixRed,
                  ),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: NivioTheme.netflixRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaybackSpeedDialog(BuildContext context, WidgetRef ref) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NivioTheme.netflixDarkGrey,
        title: const Text(
          'Playback Speed',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((speed) {
            final currentSpeed = ref.read(playbackSpeedProvider);
            return RadioListTile<double>(
              value: speed,
              groupValue: currentSpeed,
              activeColor: NivioTheme.netflixRed,
              title: Text(
                '${speed}x',
                style: const TextStyle(color: Colors.white),
              ),
              onChanged: (value) {
                if (value != null) {
                  ref.read(playbackSpeedProvider.notifier).setSpeed(value);
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showVideoQualityDialog(BuildContext context, WidgetRef ref) {
    final qualities = [
      {'value': 'auto', 'label': 'Auto (Best Available)'},
      {'value': '2160p', 'label': '4K (2160p)'},
      {'value': '1080p', 'label': 'Full HD (1080p)'},
      {'value': '720p', 'label': 'HD (720p)'},
      {'value': '480p', 'label': 'SD (480p)'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NivioTheme.netflixDarkGrey,
        title: const Text(
          'Video Quality',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: qualities.map((quality) {
            final currentQuality = ref.read(videoQualityProvider);
            return RadioListTile<String>(
              value: quality['value']!,
              groupValue: currentQuality,
              activeColor: NivioTheme.netflixRed,
              title: Text(
                quality['label']!,
                style: const TextStyle(color: Colors.white),
              ),
              onChanged: (value) {
                if (value != null) {
                  ref.read(videoQualityProvider.notifier).setQuality(value);
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
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
        backgroundColor: NivioTheme.netflixDarkGrey,
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
            ...frequencies.map((freq) {
              final currentFreq = ref.read(episodeCheckFrequencyProvider);
              return RadioListTile<int>(
                value: freq['value'] as int,
                groupValue: currentFreq,
                activeColor: NivioTheme.netflixRed,
                title: Text(
                  freq['label'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(episodeCheckFrequencyProvider.notifier)
                        .setFrequency(value);
                    Navigator.pop(dialogContext);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCheckingDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NivioTheme.netflixDarkGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: NivioTheme.netflixRed),
            const SizedBox(height: 20),
            const Text(
              'Checking for new episodes...',
              style: TextStyle(color: Colors.white),
            ),
            FutureBuilder<int>(
              future: EpisodeCheckService.checkNow(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // Auto-close dialog and show result
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
                          backgroundColor: NivioTheme.netflixRed,
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
