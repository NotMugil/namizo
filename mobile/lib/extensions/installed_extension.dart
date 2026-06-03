import 'extension_manifest.dart';

enum ExtensionTrustState { unverified, trusted, blocked }

class InstalledExtension {
  final ExtensionManifest manifest;
  final bool enabled;
  final ExtensionTrustState trustState;
  final DateTime installedAt;
  final DateTime updatedAt;

  const InstalledExtension({
    required this.manifest,
    required this.enabled,
    required this.trustState,
    required this.installedAt,
    required this.updatedAt,
  });

  InstalledExtension copyWith({
    ExtensionManifest? manifest,
    bool? enabled,
    ExtensionTrustState? trustState,
    DateTime? installedAt,
    DateTime? updatedAt,
  }) {
    return InstalledExtension(
      manifest: manifest ?? this.manifest,
      enabled: enabled ?? this.enabled,
      trustState: trustState ?? this.trustState,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory InstalledExtension.fromJson(Map<String, dynamic> json) {
    return InstalledExtension(
      manifest: ExtensionManifest.fromJson(
        json['manifest'] as Map<String, dynamic>,
      ),
      enabled: json['enabled'] as bool? ?? true,
      trustState: ExtensionTrustState.values.byName(
        json['trustState'] as String? ?? ExtensionTrustState.unverified.name,
      ),
      installedAt: DateTime.parse(json['installedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manifest': manifest.toJson(),
      'enabled': enabled,
      'trustState': trustState.name,
      'installedAt': installedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
