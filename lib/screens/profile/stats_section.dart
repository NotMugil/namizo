import 'package:flutter/material.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Anime statistics grid (count, episodes, minutes, mean score).
class StatsSection extends StatelessWidget {
  final Map<String, dynamic> viewer;

  const StatsSection({super.key, required this.viewer});

  @override
  Widget build(BuildContext context) {
    final statistics = viewer['statistics'] as Map<String, dynamic>?;
    final animeStats = statistics?['anime'] as Map<String, dynamic>?;

    final entries = [
      _StatItem(
        icon: PhosphorIconsFill.televisionSimple,
        label: 'Anime',
        value: _display(animeStats?['count']),
      ),
      _StatItem(
        icon: PhosphorIconsFill.playCircle,
        label: 'Episodes',
        value: _display(animeStats?['episodesWatched']),
      ),
      _StatItem(
        icon: PhosphorIconsFill.clock,
        label: 'Minutes',
        value: _display(animeStats?['minutesWatched']),
      ),
      _StatItem(
        icon: PhosphorIconsFill.star,
        label: 'Mean Score',
        value: _display(animeStats?['meanScore']),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 0,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final item = entries[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhosphorIcon(item.icon, color: NamizoTheme.primary, size: 15),
                const SizedBox(height: 8),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NamizoTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NamizoTheme.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _display(dynamic value) => value?.toString() ?? '-';
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}
