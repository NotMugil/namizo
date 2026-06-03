import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namizo/extensions/extension_manifest.dart';
import 'package:namizo/extensions/installed_extension.dart';
import 'package:namizo/providers/extension_manager.dart';
import 'package:namizo/providers/extensions.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ExtensionsAvailableSection extends ConsumerStatefulWidget {
  const ExtensionsAvailableSection({super.key});

  @override
  ConsumerState<ExtensionsAvailableSection> createState() =>
      _ExtensionsAvailableSectionState();
}

class _ExtensionsAvailableSectionState
    extends ConsumerState<ExtensionsAvailableSection> {
  final TextEditingController _repositoryController = TextEditingController();

  @override
  void dispose() {
    _repositoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repositoryUrls = ref.watch(extensionRepositoryUrlsProvider);
    final catalogAsync = ref.watch(extensionCatalogEntriesProvider);
    final installedById = ref.watch(installedExtensionsByIdProvider);
    final controller = ref.watch(extensionManagerControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionIntro(
              title: 'Browse repositories',
              subtitle:
                  'Add a manifest URL, then install the extensions you want to use.',
              icon: PhosphorIconsRegular.magnifyingGlass,
            ),
            const SizedBox(height: 14),
            _Panel(
              child: TextField(
                controller: _repositoryController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Manifest URL',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.plus),
                    color: Colors.white,
                    onPressed: () async {
                      final value = _repositoryController.text.trim();
                      if (value.isEmpty) return;
                      await controller.addRepositoryUrl(value);
                      _repositoryController.clear();
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (repositoryUrls.isNotEmpty)
              _Panel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final url in repositoryUrls)
                      InputChip(
                        label: Text(
                          url,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        deleteIconColor: Colors.white70,
                        onDeleted: () async {
                          await controller.removeRepositoryUrl(url);
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Available extensions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _MiniBadge(
                  label:
                      '${repositoryUrls.length} source${repositoryUrls.length == 1 ? '' : 's'}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: catalogAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return const _EmptyExtensionsState(
                      message:
                          'No extensions loaded yet. Add a manifest URL to browse available packages.',
                    );
                  }

                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final manifest = entries[index];
                      final installed = installedById[manifest.id];
                      return _ExtensionCard(
                        manifest: manifest,
                        installedExtension: installed,
                        onPrimaryAction: () async {
                          if (installed == null) {
                            await controller.installManifest(manifest);
                          } else {
                            await controller.enableExtension(
                              manifest.id,
                              !installed.enabled,
                            );
                          }
                        },
                        onRemove: installed == null
                            ? null
                            : () async {
                                await controller.removeExtension(manifest.id);
                              },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load extensions: $error',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstalledExtensionsSection extends ConsumerWidget {
  const InstalledExtensionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedExtensionsProvider);
    final controller = ref.watch(extensionManagerControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionIntro(
            title: 'Installed extensions',
            subtitle:
                'Enable, disable, inspect, or remove the extensions that are already installed on the device.',
            icon: PhosphorIconsRegular.stack,
          ),
          const SizedBox(height: 16),
          _Panel(
            child: Row(
              children: [
                _MiniBadge(label: '${installed.length} installed'),
                const SizedBox(width: 8),
                _MiniBadge(
                  label:
                      '${installed.where((extension) => extension.enabled).length} enabled',
                  tone: _BadgeTone.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: installed.isEmpty
                ? const _EmptyExtensionsState(
                    message:
                        'No extensions are installed yet. Add a manifest URL and install one from the browse tab.',
                  )
                : ListView.separated(
                    itemCount: installed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final extension = installed[index];
                      return _ExtensionCard(
                        manifest: extension.manifest,
                        installedExtension: extension,
                        onTap: () => _showExtensionDetails(context, extension),
                        onPrimaryAction: () async {
                          await controller.enableExtension(
                            extension.manifest.id,
                            !extension.enabled,
                          );
                        },
                        onRemove: () async {
                          await controller.removeExtension(
                            extension.manifest.id,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({
    required this.manifest,
    required this.installedExtension,
    required this.onPrimaryAction,
    required this.onRemove,
    this.onTap,
  });

  final ExtensionManifest manifest;
  final InstalledExtension? installedExtension;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final installed = installedExtension != null;
    final enabled = installedExtension?.enabled ?? false;

    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoAvatar(logoUrl: manifest.logoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              manifest.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (installed)
                            _MiniBadge(
                              label: enabled ? 'Enabled' : 'Disabled',
                              tone: enabled
                                  ? _BadgeTone.success
                                  : _BadgeTone.muted,
                            )
                          else
                            const _MiniBadge(label: 'Available'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${manifest.author} • ${manifest.version}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        manifest.description.isEmpty
                            ? 'No description provided.'
                            : manifest.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MiniBadge(
                            label: manifest.capabilities.isEmpty
                                ? 'Metadata'
                                : manifest.capabilities
                                      .map((capability) => capability.name)
                                      .join(' • '),
                          ),
                          if (installedExtension != null)
                            _MiniBadge(
                              label: _trustLabel(
                                installedExtension!.trustState,
                              ),
                              tone: _trustTone(installedExtension!.trustState),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (installed)
                      Switch(
                        value: enabled,
                        onChanged: (_) => onPrimaryAction(),
                        activeThumbColor: NamizoTheme.primary,
                      )
                    else
                      ElevatedButton(
                        onPressed: onPrimaryAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NamizoTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Install'),
                      ),
                    if (onRemove != null)
                      IconButton(
                        onPressed: onRemove,
                        icon: const PhosphorIcon(PhosphorIconsRegular.trash),
                        color: Colors.white70,
                        tooltip: 'Remove extension',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({required this.logoUrl});

  final Uri? logoUrl;

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null) {
      return CircleAvatar(
        backgroundColor: NamizoTheme.primary.withValues(alpha: 0.2),
        backgroundImage: NetworkImage(logoUrl.toString()),
      );
    }

    return CircleAvatar(
      backgroundColor: NamizoTheme.primary.withValues(alpha: 0.2),
      child: const Text(
        'EX',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Future<void> _showExtensionDetails(
  BuildContext context,
  InstalledExtension extension,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _ExtensionDetailSheet(extension: extension);
    },
  );
}

class _ExtensionDetailSheet extends ConsumerWidget {
  const _ExtensionDetailSheet({required this.extension});

  final InstalledExtension extension;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(extensionManagerControllerProvider);
    final manifest = extension.manifest;
    final capabilityText = manifest.capabilities.isEmpty
        ? 'Metadata'
        : manifest.capabilities
              .map((capability) => capability.name)
              .join(' • ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111317),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LogoAvatar(logoUrl: manifest.logoUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            manifest.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${manifest.author} • ${manifest.version}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MiniBadge(
                                label: extension.enabled
                                    ? 'Enabled'
                                    : 'Disabled',
                                tone: extension.enabled
                                    ? _BadgeTone.success
                                    : _BadgeTone.muted,
                              ),
                              _MiniBadge(
                                label: _trustLabel(extension.trustState),
                                tone: _trustTone(extension.trustState),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoBlock(label: 'Description', value: manifest.description),
                const SizedBox(height: 12),
                _InfoBlock(label: 'Capabilities', value: capabilityText),
                const SizedBox(height: 12),
                _InfoBlock(
                  label: 'Source',
                  value: manifest.updateUrl?.toString() ?? 'Not provided',
                ),
                const SizedBox(height: 12),
                _InfoBlock(label: 'Entrypoint', value: manifest.entrypoint),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await controller.enableExtension(
                            manifest.id,
                            !extension.enabled,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(extension.enabled ? 'Disable' : 'Enable'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await controller.removeExtension(manifest.id);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEB4D4B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: NamizoTheme.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: NamizoTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _BadgeTone { muted, success, warning, danger }

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, this.tone = _BadgeTone.muted});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _BadgeTone.success => (
        NamizoTheme.primary.withValues(alpha: 0.16),
        NamizoTheme.primary,
      ),
      _BadgeTone.warning => (const Color(0xFF3B2F12), const Color(0xFFF5C451)),
      _BadgeTone.danger => (const Color(0xFF3B1717), const Color(0xFFFF7B7B)),
      _BadgeTone.muted => (
        Colors.white.withValues(alpha: 0.08),
        Colors.white70,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _trustLabel(ExtensionTrustState state) {
  switch (state) {
    case ExtensionTrustState.trusted:
      return 'Trusted';
    case ExtensionTrustState.blocked:
      return 'Blocked';
    case ExtensionTrustState.unverified:
      return 'Unverified';
  }
}

_BadgeTone _trustTone(ExtensionTrustState state) {
  switch (state) {
    case ExtensionTrustState.trusted:
      return _BadgeTone.success;
    case ExtensionTrustState.blocked:
      return _BadgeTone.danger;
    case ExtensionTrustState.unverified:
      return _BadgeTone.warning;
  }
}

class _EmptyExtensionsState extends StatelessWidget {
  const _EmptyExtensionsState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
