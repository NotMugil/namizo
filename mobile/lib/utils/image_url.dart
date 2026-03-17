import 'package:namizo/core/constants.dart';

/// Returns a fully-qualified poster URL for a given [posterPath].
/// Handles relative Kuroiru paths, absolute URLs, and empty/null values.
String posterUrl(String? posterPath, {String size = posterSize}) {
  if (posterPath == null || posterPath.isEmpty) return '';
  if (posterPath.startsWith('http://') || posterPath.startsWith('https://')) {
    return posterPath;
  }
  if (posterPath.startsWith('/')) {
    return 'https://kuroiru.co$posterPath';
  }
  return posterPath;
}

/// Returns a fully-qualified backdrop URL for a given [backdropPath].
/// Handles relative Kuroiru paths, absolute URLs, and empty/null values.
String backdropUrl(String? backdropPath, {String size = backdropSize}) {
  if (backdropPath == null || backdropPath.isEmpty) return '';
  if (backdropPath.startsWith('http://') ||
      backdropPath.startsWith('https://')) {
    return backdropPath;
  }
  if (backdropPath.startsWith('/')) {
    return 'https://kuroiru.co$backdropPath';
  }
  return backdropPath;
}
