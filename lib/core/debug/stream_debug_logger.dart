import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class StreamDebugLogger {
  static const String _logFileName = 'namizo_stream_debug.log';
  static const String _latestM3u8FileName = 'namizo_latest_m3u8_url.txt';

  static Future<void> logOpenedStream({
    required int mediaId,
    required int season,
    required int episode,
    required String provider,
    required String url,
    required bool isM3u8,
  }) async {
    if (!kDebugMode) return;

    final now = DateTime.now().toIso8601String();
    final payload = {
      'timestamp': now,
      'mediaId': mediaId,
      'season': season,
      'episode': episode,
      'provider': provider,
      'isM3u8': isM3u8,
      'url': url,
    };

    try {
      final dir = Directory.systemTemp;
      final logFile = File('${dir.path}${Platform.pathSeparator}$_logFileName');
      if (!await logFile.exists()) {
        await logFile.create(recursive: true);
      }
      await logFile.writeAsString('${jsonEncode(payload)}\n', mode: FileMode.append);

      if (isM3u8) {
        final latestFile =
            File('${dir.path}${Platform.pathSeparator}$_latestM3u8FileName');
        if (!await latestFile.exists()) {
          await latestFile.create(recursive: true);
        }
        await latestFile.writeAsString(url, mode: FileMode.write);
      }

      debugPrint('[StreamDebugLogger] wrote stream debug to ${logFile.path}');
    } catch (e) {
      debugPrint('[StreamDebugLogger] failed to write debug file: $e');
    }
  }
}
