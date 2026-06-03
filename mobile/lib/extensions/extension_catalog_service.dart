import 'package:dio/dio.dart';

import 'extension_manifest.dart';

class ExtensionCatalogService {
  final Dio _dio;

  ExtensionCatalogService({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<ExtensionManifest>> loadCatalog(Uri source) async {
    final response = await _dio.getUri(source);
    final data = response.data;

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => ExtensionManifest.fromJson(_castMap(item)))
          .toList();
    }

    if (data is Map) {
      final map = _castMap(data);
      if (map['extensions'] is List) {
        return (map['extensions'] as List)
            .whereType<Map>()
            .map((item) => ExtensionManifest.fromJson(_castMap(item)))
            .toList();
      }

      return [ExtensionManifest.fromJson(map)];
    }

    return [];
  }

  Map<String, dynamic> _castMap(Map value) {
    return value.map((key, dynamic value) => MapEntry(key.toString(), value));
  }
}
