import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/extensions/extension_catalog_service.dart';
import 'package:namizo/extensions/extension_host.dart';
import 'package:namizo/extensions/extension_manifest.dart';
import 'package:namizo/extensions/extension_registry.dart';
import 'package:namizo/providers/extensions.dart';

final extensionCatalogServiceProvider = Provider<ExtensionCatalogService>((
  ref,
) {
  return ExtensionCatalogService();
});

final extensionRepositoryUrlsProvider = Provider<List<String>>((ref) {
  return ref.watch(extensionRegistryProvider).repositoryUrls;
});

final extensionCatalogEntriesProvider = FutureProvider<List<ExtensionManifest>>(
  (ref) async {
    final registry = ref.watch(extensionRegistryProvider);
    final service = ref.watch(extensionCatalogServiceProvider);
    final entries = <ExtensionManifest>[];

    for (final url in registry.repositoryUrls) {
      try {
        final loaded = await service.loadCatalog(Uri.parse(url));
        entries.addAll(loaded);
      } catch (_) {
        continue;
      }
    }

    return entries;
  },
);

final extensionInstalledCatalogEntriesProvider =
    Provider<List<ExtensionManifest>>((ref) {
      final installedIds = ref
          .watch(installedExtensionsProvider)
          .map((e) => e.manifest.id)
          .toSet();
      final entries =
          ref.watch(extensionCatalogEntriesProvider).valueOrNull ??
          const <ExtensionManifest>[];
      return entries.where((entry) => installedIds.contains(entry.id)).toList();
    });

class ExtensionManagerController {
  ExtensionManagerController(this._registry);

  final ExtensionRegistry _registry;

  Future<void> addRepositoryUrl(String url) => _registry.addRepositoryUrl(url);

  Future<void> removeRepositoryUrl(String url) =>
      _registry.removeRepositoryUrl(url);

  Future<void> enableExtension(String id, bool enabled) =>
      _registry.setEnabled(id, enabled);

  Future<void> removeExtension(String id) => _registry.remove(id);

  Future<void> installManifest(ExtensionManifest manifest) =>
      _registry.upsertManifest(manifest);
}

final extensionManagerControllerProvider = Provider<ExtensionManagerController>(
  (ref) {
    return ExtensionManagerController(ExtensionHost.instance.registry);
  },
);
