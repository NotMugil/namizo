import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/models/update_info.dart';
import 'package:namizo/services/update.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.update});

  final UpdateInfo update;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _errorMessage = null;
    });

    final success = await UpdateService.downloadAndInstall(
      widget.update.downloadUrl,
      (p) => setState(() => _progress = p),
    );

    if (!mounted) return;
    if (!success) {
      setState(() {
        _downloading = false;
        _errorMessage = 'Download failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final changelog = widget.update.changelog;
    final lines = changelog.split('\n');
    final preview = lines.take(8).join('\n');
    final truncated = lines.length > 8;

    return Dialog(
      backgroundColor: NamizoTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NamizoTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const PhosphorIcon(
                    PhosphorIconsFill.arrowCircleUp,
                    color: NamizoTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.update.currentVersion} -> v${widget.update.latestVersion}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (changelog.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What's new",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: NamizoTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      truncated ? '$preview\n...' : preview,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_downloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading update...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: NamizoTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(
                        NamizoTheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NamizoTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Update Now',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
