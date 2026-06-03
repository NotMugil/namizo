import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:namizo/extensions/extension_host.dart';
import 'package:namizo/extensions/extension_registry.dart';
import 'package:namizo/extensions/installed_extension.dart';

final extensionRegistryProvider = ChangeNotifierProvider<ExtensionRegistry>((
  ref,
) {
  return ExtensionHost.instance.registry;
});

final installedExtensionsProvider = Provider<List<InstalledExtension>>((ref) {
  return ref.watch(extensionRegistryProvider).installedExtensions;
});

final installedExtensionsByIdProvider =
    Provider<Map<String, InstalledExtension>>((ref) {
      final extensions = ref.watch(installedExtensionsProvider);
      return {
        for (final extension in extensions) extension.manifest.id: extension,
      };
    });
