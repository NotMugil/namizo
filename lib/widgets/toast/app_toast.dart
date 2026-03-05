import 'package:flutter/material.dart';

import 'app_toast_style.dart';

class AppToast {
  static void show({
    required BuildContext context,
    required String message,
    required IconData icon,
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
            Icon(icon, color: accent, size: 18),
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
