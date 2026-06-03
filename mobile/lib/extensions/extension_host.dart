import 'package:shared_preferences/shared_preferences.dart';

import 'extension_registry.dart';

class ExtensionHost {
  ExtensionHost._();

  static final ExtensionHost instance = ExtensionHost._();

  ExtensionRegistry? _registry;

  ExtensionRegistry get registry {
    final registry = _registry;
    if (registry == null) {
      throw StateError('ExtensionHost has not been initialized.');
    }

    return registry;
  }

  bool get isInitialized => _registry != null;

  Future<void> initialize() async {
    if (_registry != null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final registry = ExtensionRegistry(prefs);
    await registry.load();
    _registry = registry;
  }
}
