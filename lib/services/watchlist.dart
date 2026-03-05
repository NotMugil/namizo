import 'package:hive/hive.dart';
import 'package:namizo/core/config.dart';
import 'package:namizo/models/user/watchlist_item.dart';

class WatchlistService {
  static const String _boxName = AppConfigurations.watchlistBoxName;

  Box<WatchlistItem> get _box => Hive.box<WatchlistItem>(_boxName);

  static Future<void> init() async {
    await Hive.openBox<WatchlistItem>(_boxName);
  }

  bool isInWatchlist(int mediaId) => _box.containsKey(mediaId);

  List<WatchlistItem> getAllItems() {
    return _box.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  Future<void> addToWatchlist(WatchlistItem item) async {
    await _box.put(item.id, item);
  }

  Future<void> removeFromWatchlist(int mediaId) async {
    await _box.delete(mediaId);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  int get count => _box.length;
}
