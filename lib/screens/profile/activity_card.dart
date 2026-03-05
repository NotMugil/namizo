import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/widgets/toast/app_toast.dart';
import 'package:namizo/utils/status.dart';
import 'package:namizo/utils/time.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A single activity entry shown in the profile Recent Activity list.
class ActivityCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> activity;
  final String username;
  final String? avatarUrl;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.username,
    required this.avatarUrl,
  });

  @override
  ConsumerState<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends ConsumerState<ActivityCard> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final media = activity['media'] as Map<String, dynamic>?;
    final mediaId = (media?['id'] as num?)?.toInt();
    final title =
        ((media?['title'] as Map<String, dynamic>?)?['userPreferred'] ??
                'Unknown title')
            .toString();
    final coverUrl =
        ((media?['coverImage'] as Map<String, dynamic>?)?['large'])?.toString();
    final createdAt = (activity['createdAt'] as num?)?.toInt();

    final user = activity['user'] as Map<String, dynamic>?;
    final activityUsername =
        (user?['name']?.toString().trim().isNotEmpty == true)
            ? user!['name'].toString().trim()
            : widget.username;
    final activityAvatar = user?['avatar'] as Map<String, dynamic>?;
    final activityAvatarUrl = activityAvatar?['large']?.toString() ??
        activityAvatar?['medium']?.toString() ??
        widget.avatarUrl;

    final statusRaw = (activity['status'] ?? '').toString();
    final statusNormalized = _statusFromActivity(statusRaw);
    final progress = (activity['progress'] ?? '').toString().trim();
    final actionText = _activityActionText(statusNormalized, progress);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar, username, timestamp
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: NamizoTheme.netflixDarkGrey,
                  backgroundImage: (activityAvatarUrl != null &&
                          activityAvatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(activityAvatarUrl)
                      : null,
                  child: (activityAvatarUrl == null ||
                          activityAvatarUrl.isEmpty)
                      ? const PhosphorIcon(
                          PhosphorIconsRegular.user,
                          color: NamizoTheme.netflixWhite,
                          size: 11,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    activityUsername,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NamizoTheme.netflixWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '•',
                  style: TextStyle(
                    color: NamizoTheme.netflixGrey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  relativeTimeFromSeconds(createdAt),
                  style: const TextStyle(
                    color: NamizoTheme.netflixGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Content row: cover image + metadata
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 74,
                    child: (coverUrl != null && coverUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(color: NamizoTheme.netflixDarkGrey),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NamizoTheme.netflixLightGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NamizoTheme.netflixWhite,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: (mediaId == null || _isUpdating)
                            ? null
                            : () => _showStatusSelector(
                                  mediaId: mediaId,
                                  currentStatus: statusNormalized,
                                ),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: NamizoTheme.netflixRed
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isUpdating)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: NamizoTheme.netflixRed,
                                  ),
                                )
                              else
                                Text(
                                  statusLabel(statusNormalized),
                                  style: const TextStyle(
                                    color: NamizoTheme.netflixWhite,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              const SizedBox(width: 6),
                              const PhosphorIcon(
                                PhosphorIconsRegular.caretDown,
                                color: NamizoTheme.netflixWhite,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusSelector({
    required int mediaId,
    required String currentStatus,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        const options = <String>[
          'CURRENT',
          'PLANNING',
          'COMPLETED',
          'DROPPED',
          'PAUSED',
          'REPEATING',
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Change status',
                    style: TextStyle(
                      color: NamizoTheme.netflixWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...options.map((status) {
                  final isSelected = currentStatus == status;
                  return ListTile(
                    dense: true,
                    onTap: () => Navigator.of(context).pop(status),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: isSelected
                        ? const PhosphorIcon(
                            PhosphorIconsFill.checkCircle,
                            color: NamizoTheme.netflixRed,
                            size: 18,
                          )
                        : const SizedBox(width: 18),
                    title: Text(
                      statusLabel(status),
                      style: TextStyle(
                        color: isSelected
                            ? NamizoTheme.netflixWhite
                            : NamizoTheme.netflixLightGrey,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected == currentStatus) return;

    setState(() => _isUpdating = true);
    final ok = await ref.read(aniListServiceProvider).updateStatusByMediaId(
          mediaId: mediaId,
          status: selected,
        );
    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (ok) {
      ref.read(aniListAccountRefreshProvider.notifier).state++;
      AppToast.show(
        context: context,
        message: 'Status updated to ${statusLabel(selected)}',
        icon: PhosphorIconsFill.checkCircle,
        accent: const Color(0xFF22C55E),
      );
    } else {
      AppToast.show(
        context: context,
        message: 'Failed to update status',
        icon: PhosphorIconsRegular.warning,
        accent: const Color(0xFFF59E0B),
      );
    }
  }

  String _statusFromActivity(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('dropped')) return 'DROPPED';
    if (s.contains('complete')) return 'COMPLETED';
    if (s.contains('paused')) return 'PAUSED';
    if (s.contains('repeat')) return 'REPEATING';
    if (s.contains('plan')) return 'PLANNING';
    return 'CURRENT';
  }

  String _activityActionText(String status, String progress) {
    switch (status) {
      case 'PLANNING':
        return 'Plans to watch';
      case 'COMPLETED':
        return 'Completed';
      case 'DROPPED':
        return 'Dropped';
      case 'PAUSED':
        return 'Paused';
      case 'REPEATING':
        return 'Rewatching';
      case 'CURRENT':
      default:
        return progress.isNotEmpty ? 'Watching $progress' : 'Watching';
    }
  }
}
