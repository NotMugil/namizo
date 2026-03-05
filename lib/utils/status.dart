/// Normalizes an AniList watch status string to one of:
/// WATCHING, PLANNING, PAUSED, DROPPED, COMPLETED.
String normalizeWatchStatus(String? rawStatus) {
  switch ((rawStatus ?? '').toUpperCase()) {
    case 'PLANNING':
      return 'PLANNING';
    case 'PAUSED':
      return 'PAUSED';
    case 'DROPPED':
      return 'DROPPED';
    case 'COMPLETED':
      return 'COMPLETED';
    case 'CURRENT':
    case 'REPEATING':
    default:
      return 'WATCHING';
  }
}

/// Returns a human-readable label for an AniList watch status.
String statusLabel(String status) {
  switch (status) {
    case 'CURRENT':
      return 'Watching';
    case 'PLANNING':
      return 'Planning';
    case 'COMPLETED':
      return 'Completed';
    case 'DROPPED':
      return 'Dropped';
    case 'PAUSED':
      return 'Paused';
    case 'REPEATING':
      return 'Rewatching';
    default:
      return status;
  }
}
