/// Returns a human-readable relative time string for a Unix timestamp
/// given in seconds (e.g. "3 hours ago", "just now").
String relativeTimeFromSeconds(int? createdAtSeconds) {
  if (createdAtSeconds == null || createdAtSeconds <= 0) return 'just now';
  final created = DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000);
  final diff = DateTime.now().difference(created);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) {
    final value = diff.inMinutes;
    return '$value minute${value == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final value = diff.inHours;
    return '$value hour${value == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 30) {
    final value = diff.inDays;
    return '$value day${value == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 365) {
    final value = (diff.inDays / 30).floor();
    return '$value month${value == 1 ? '' : 's'} ago';
  }

  final value = (diff.inDays / 365).floor();
  return '$value year${value == 1 ? '' : 's'} ago';
}
