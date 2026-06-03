import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'extension_manifest.dart';
import 'installed_extension.dart';

class ExtensionRegistry extends ChangeNotifier {
  static const String _storageKey = 'extension_registry.v1';
  static const String _sourcesKey = 'extension_sources.v1';

  final SharedPreferences _prefs;
  final List<InstalledExtension> _extensions = [];
  final List<String> _repositoryUrls = [];

  ExtensionRegistry(this._prefs);

  List<InstalledExtension> get installedExtensions =>
      List.unmodifiable(_extensions);

  List<String> get repositoryUrls => List.unmodifiable(_repositoryUrls);

  Future<void> load() async {
    _extensions
      ..clear()
      ..addAll(_readPersistedExtensions());

    _repositoryUrls
      ..clear()
      ..addAll(_readPersistedRepositoryUrls());

    notifyListeners();
  }

  InstalledExtension? byId(String id) {
    for (final extension in _extensions) {
      if (extension.manifest.id == id) {
        return extension;
      }
    }

    return null;
  }

  Future<void> upsertManifest(
    ExtensionManifest manifest, {
    bool enabled = true,
    ExtensionTrustState trustState = ExtensionTrustState.unverified,
  }) async {
    final now = DateTime.now();
    final current = byId(manifest.id);
    final extension = InstalledExtension(
      manifest: manifest,
      enabled: enabled,
      trustState: trustState,
      installedAt: current?.installedAt ?? now,
      updatedAt: now,
    );

    _replace(extension);
    await _persist();
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final current = byId(id);
    if (current == null) {
      return;
    }

    _replace(current.copyWith(enabled: enabled, updatedAt: DateTime.now()));
    await _persist();
    notifyListeners();
  }

  Future<void> setTrustState(String id, ExtensionTrustState trustState) async {
    final current = byId(id);
    if (current == null) {
      return;
    }

    _replace(
      current.copyWith(trustState: trustState, updatedAt: DateTime.now()),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _extensions.removeWhere((extension) => extension.manifest.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _extensions.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> addRepositoryUrl(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty || _repositoryUrls.contains(normalized)) {
      return;
    }

    _repositoryUrls.add(normalized);
    await _persistSources();
    notifyListeners();
  }

  Future<void> removeRepositoryUrl(String url) async {
    _repositoryUrls.remove(url);
    await _persistSources();
    notifyListeners();
  }

  List<InstalledExtension> _readPersistedExtensions() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => InstalledExtension.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _replace(InstalledExtension extension) {
    _extensions.removeWhere(
      (current) => current.manifest.id == extension.manifest.id,
    );
    _extensions.add(extension);
  }

  List<String> _readPersistedRepositoryUrls() {
    final raw = _prefs.getString(_sourcesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((value) => value as String).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _storageKey,
      jsonEncode(_extensions.map((extension) => extension.toJson()).toList()),
    );
    await _persistSources();
  }

  Future<void> _persistSources() async {
    await _prefs.setString(_sourcesKey, jsonEncode(_repositoryUrls));
  }
}
