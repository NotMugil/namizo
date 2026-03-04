import 'dart:convert';

class CacheCodec {
  const CacheCodec._();

  static Map<String, dynamic> decodeMap(String value) {
    return json.decode(value) as Map<String, dynamic>;
  }

  static List<dynamic> decodeList(String value) {
    return json.decode(value) as List<dynamic>;
  }

  static String encode(dynamic value) {
    return json.encode(value);
  }
}
