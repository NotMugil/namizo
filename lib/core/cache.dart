import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:namizo/core/constants.dart';
import 'package:namizo/models/cache/cache_entry.dart';

class CacheService {
  late Box<CacheEntry> _box;

  Future<void> init() async {
    _box = await Hive.openBox<CacheEntry>(cacheBoxName);
    await _cleanExpiredEntries();
  }

  Future<T?> get<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final entry = _box.get(key);
      if (entry == null) return null;
      if (entry.isExpired) {
        await _box.delete(key);
        return null;
      }
      final jsonData = json.decode(entry.data) as Map<String, dynamic>;
      return fromJson(jsonData);
    } catch (_) {
      await _box.delete(key);
      return null;
    }
  }

  Future<List<T>?> getList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final entry = _box.get(key);
      if (entry == null) return null;
      if (entry.isExpired) {
        await _box.delete(key);
        return null;
      }
      final jsonList = json.decode(entry.data) as List<dynamic>;
      return jsonList
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await _box.delete(key);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRaw(String key) async {
    try {
      final entry = _box.get(key);
      if (entry == null) return null;
      if (entry.isExpired) {
        await _box.delete(key);
        return null;
      }
      return json.decode(entry.data) as Map<String, dynamic>;
    } catch (_) {
      await _box.delete(key);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStaleRaw(String key) async {
    try {
      final entry = _box.get(key);
      if (entry == null) return null;
      return json.decode(entry.data) as Map<String, dynamic>;
    } catch (_) {
      await _box.delete(key);
      return null;
    }
  }

  bool isExpired(String key) {
    final entry = _box.get(key);
    return entry?.isExpired ?? true;
  }

  Future<void> set(String key, dynamic data, {Duration ttl = mediumCache}) async {
    try {
      final entry = CacheEntry(
        key: key,
        data: json.encode(data),
        timestamp: DateTime.now(),
        ttlMilliseconds: ttl.inMilliseconds,
      );
      await _box.put(key, entry);
    } catch (_) {}
  }

  Future<void> updateInBackground(
    String key,
    Future<dynamic> Function() fetchFn,
    Duration ttl, {
    int maxRetries = 3,
  }) async {
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final data = await fetchFn();
        await set(key, data, ttl: ttl);
        return;
      } catch (_) {
        retryCount++;
        if (retryCount >= maxRetries) return;
        final waitTime = Duration(seconds: (1 << (retryCount - 1)));
        await Future.delayed(waitTime);
      }
    }
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  Future<void> _cleanExpiredEntries() async {
    Future.delayed(const Duration(seconds: 2), () async {
      final expiredKeys = <String>[];
      for (final entry in _box.values) {
        if (entry.isExpired) {
          expiredKeys.add(entry.key);
        }
      }
      for (final key in expiredKeys) {
        await _box.delete(key);
      }
    });
  }

  Map<String, dynamic> getStats() {
    final total = _box.length;
    var expired = 0;
    var valid = 0;

    for (final entry in _box.values) {
      if (entry.isExpired) {
        expired++;
      } else {
        valid++;
      }
    }

    return {'total': total, 'valid': valid, 'expired': expired};
  }

  Future<void> close() async {
    await _box.close();
  }
}
