import 'extension_capability.dart';

class ExtensionManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final Uri? logoUrl;
  final Uri? homepageUrl;
  final Uri? updateUrl;
  final String entrypoint;
  final List<ExtensionCapability> capabilities;
  final List<String> permissions;

  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.entrypoint,
    this.logoUrl,
    this.homepageUrl,
    this.updateUrl,
    this.capabilities = const [],
    this.permissions = const [],
  });

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    return ExtensionManifest(
      id: _stringValue(idValue),
      name: json['name'] as String,
      version: _stringValue(json['version']),
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      logoUrl: _parseUri(
        (json['logoUrl'] as String?) ?? (json['iconUrl'] as String?),
      ),
      homepageUrl: _parseUri(json['homepageUrl'] as String?),
      updateUrl: _parseUri(
        (json['updateUrl'] as String?) ?? (json['sourceCodeUrl'] as String?),
      ),
      entrypoint:
          json['entrypoint'] as String? ??
          (json['sourceCodeUrl'] as String? ?? 'main'),
      capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
          .map((value) => ExtensionCapability.values.byName(value as String))
          .toList(),
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((value) => value as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'author': author,
      'logoUrl': logoUrl?.toString(),
      'homepageUrl': homepageUrl?.toString(),
      'updateUrl': updateUrl?.toString(),
      'entrypoint': entrypoint,
      'capabilities': capabilities
          .map((capability) => capability.name)
          .toList(),
      'permissions': permissions,
    };
  }

  static Uri? _parseUri(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return Uri.tryParse(value);
  }

  static String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }
}
