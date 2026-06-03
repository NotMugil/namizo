import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/screens/settings/extension_manager_sheet.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ExtensionsPage extends ConsumerWidget {
  const ExtensionsPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex.clamp(0, 1).toInt(),
      child: Scaffold(
        backgroundColor: NamizoTheme.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: NamizoTheme.background,
          title: const Text('Extensions', style: NamizoTheme.pageHeaderStyle),
          leading: IconButton(
            icon: const PhosphorIcon(
              PhosphorIconsRegular.caretLeft,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: NamizoTheme.primary,
            tabs: [
              Tab(text: 'Browse'),
              Tab(text: 'Installed'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ExtensionsAvailableSection(),
            InstalledExtensionsSection(),
          ],
        ),
      ),
    );
  }
}
