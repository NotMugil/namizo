import 'dart:io';

import 'package:dio/dio.dart';
import 'package:namizo/models/update_info.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateService {
  static const String _releasesApiUrl =
      'https://api.github.com/repos/NotMugil/namizo/releases/latest';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/vnd.github+json'},
    ),
  );

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final response = await _dio.get<Map<String, dynamic>>(_releasesApiUrl);
      final data = response.data;
      if (data == null) return null;

      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      final body = data['body'] as String? ?? '';
      final assets = data['assets'] as List<dynamic>? ?? [];
      final downloadUrl = _pickApkUrl(assets);
      if (downloadUrl == null) return null;

      return UpdateInfo(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        changelog: body.trim(),
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _pickApkUrl(List<dynamic> assets) {
    for (final asset in assets) {
      final map = asset is Map ? asset : null;
      final name = (map?['name'] as String? ?? '').toLowerCase();
      if (name.contains('arm64') && name.endsWith('.apk')) {
        return map?['browser_download_url'] as String?;
      }
    }

    for (final asset in assets) {
      final map = asset is Map ? asset : null;
      final name = (map?['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        return map?['browser_download_url'] as String?;
      }
    }
    return null;
  }

  static Future<bool> downloadAndInstall(
    String url,
    void Function(double progress) onProgress,
  ) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          final result = await Permission.requestInstallPackages.request();
          if (!result.isGranted) {
            await openAppSettings();
            return false;
          }
        }
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/namizo_update.apk';

      await _dio.download(
        url,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
