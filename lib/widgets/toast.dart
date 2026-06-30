import 'package:flutter/material.dart';
import 'package:namizo/theme/toast_style.dart';
import 'package:namizo/widgets/app_icon.dart';

class AppToast {
  static void show({
    required BuildContext context,
    required String message,
    required Object icon,
    required Color accent,
    Duration duration = AppToastStyle.duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: AppToastStyle.margin,
        elevation: AppToastStyle.elevation,
        duration: duration,
        backgroundColor: AppToastStyle.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppToastStyle.borderRadius,
          side: AppToastStyle.border(accent),
        ),
        content: Row(
          children: [
            AppIcon(icon, color: accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppToastStyle.messageTextStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
