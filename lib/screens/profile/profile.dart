import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/screens/profile/activity_card.dart';
import 'package:namizo/screens/profile/profile_header.dart';
import 'package:namizo/screens/profile/stats_section.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aniListViewerAsync = ref.watch(aniListViewerProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/home');
      },
      child: aniListViewerAsync.when(
        loading: () => const Scaffold(
          backgroundColor: NamizoTheme.background,
          body: Center(
            child: CircularProgressIndicator(color: NamizoTheme.primary),
          ),
        ),
        error: (_, __) => _LoggedOutView(),
        data: (viewer) {
          if (viewer == null) return _LoggedOutView();

          final username = (viewer['name'] ?? 'AniList User').toString();
          final avatar = viewer['avatar'] as Map<String, dynamic>?;
          final avatarUrl =
              avatar?['large']?.toString() ?? avatar?['medium']?.toString();

          return Scaffold(
            backgroundColor: NamizoTheme.background,
            body: Column(
              children: [
                ProfileHeader(viewer: viewer),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    children: [
                      StatsSection(viewer: viewer),
                      const SizedBox(height: 2),
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          color: NamizoTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _ActivitiesSection(
                        username: username,
                        avatarUrl: avatarUrl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoggedOutView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NamizoTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please login to use this feature',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NamizoTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 190,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NamizoTheme.primary,
                    foregroundColor: NamizoTheme.textPrimary,
                    minimumSize: const Size(190, 48),
                  ),
                  onPressed: () async {
                    final result = await context.push<bool>('/anilist-login');
                    if (result == true) {
                      ref.read(aniListAccountRefreshProvider.notifier).state++;
                    }
                  },
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: NamizoTheme.primary,
                  minimumSize: const Size(190, 44),
                ),
                onPressed: () => context.push('/settings'),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.gear,
                  size: 18,
                  color: NamizoTheme.primary,
                ),
                label: const Text('Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitiesSection extends ConsumerWidget {
  final String username;
  final String? avatarUrl;

  const _ActivitiesSection({required this.username, required this.avatarUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(aniListActivitiesProvider).when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: NamizoTheme.primary),
            ),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Unable to load activities',
                style: TextStyle(color: NamizoTheme.textSecondary),
              ),
            ),
          ),
          data: (activities) {
            if (activities.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No activities found',
                    style: TextStyle(color: NamizoTheme.textSecondary),
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: activities.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) => ActivityCard(
                activity: activities[index],
                username: username,
                avatarUrl: avatarUrl,
              ),
            );
          },
        );
  }
}
