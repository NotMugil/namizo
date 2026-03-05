import 'package:namizo/core/config.dart';

class CacheConstants {
  const CacheConstants._();

  static const String boxName = AppConfigurations.tmdbCacheBoxName;

  static const Duration shortCache = Duration(minutes: 15);
  static const Duration mediumCache = Duration(hours: 1);
  static const Duration longCache = Duration(hours: 24);
  static const Duration extraLongCache = Duration(days: 7);
}
