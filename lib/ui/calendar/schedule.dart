import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unreadCount = EpisodeCheckService.getUnreadCount();

    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: NamizoTheme.netflixBlack,
        automaticallyImplyLeading: false,
        title: Text(
          'Schedule',
          style: NamizoTheme.pageHeaderStyle.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: Stack(
              children: [
                const PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  color: Colors.white,
                  size: 22,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: NamizoTheme.netflixRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(
                PhosphorIconsRegular.calendarBlank,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 14),
              const Text(
                'Schedule view',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Episode schedules and calendar timelines will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.push('/notifications'),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.bell,
                  color: NamizoTheme.netflixRed,
                  size: 18,
                ),
                label: const Text(
                  'Open Notifications',
                  style: TextStyle(color: NamizoTheme.netflixRed),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: NamizoTheme.netflixRed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
