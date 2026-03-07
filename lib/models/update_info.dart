class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.changelog,
    required this.downloadUrl,
  });

  final String latestVersion;
  final String currentVersion;
  final String changelog;
  final String downloadUrl;

  bool get isUpdateAvailable {
    try {
      final latest = latestVersion.split('.').map(int.parse).toList();
      final current = currentVersion.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final l = i < latest.length ? latest[i] : 0;
        final c = i < current.length ? current[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
