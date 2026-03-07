import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:namizo/core/cache.dart';
import 'package:namizo/models/cache/cache_entry.dart';
import 'package:namizo/models/user/new_episode.dart';
import 'package:namizo/models/user/watchlist_item.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/providers/update.dart';
import 'package:namizo/routes/routes.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/services/watchlist.dart';
import 'package:namizo/theme/font_family.dart';
import 'package:namizo/theme/theme.dart';
import 'package:namizo/widgets/update_dialog.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await _initHive();

  final cacheService = CacheService();
  await cacheService.init();

  await EpisodeCheckService.init();

  runApp(
    ProviderScope(
      overrides: [cacheServiceProvider.overrideWithValue(cacheService)],
      child: const NamizoApp(),
    ),
  );

  FlutterNativeSplash.remove();
}

Future<void> _initHive() async {
  await Hive.initFlutter();
  Hive.registerAdapter(CacheEntryAdapter());
  Hive.registerAdapter(WatchlistItemAdapter());
  Hive.registerAdapter(NewEpisodeAdapter());
  await WatchlistService.init();
}

class NamizoApp extends ConsumerStatefulWidget {
  const NamizoApp({super.key});

  @override
  ConsumerState<NamizoApp> createState() => _NamizoAppState();
}

class _NamizoAppState extends ConsumerState<NamizoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final disabled = ref.read(updateReminderDisabledProvider);
    if (disabled) return;

    final update = await ref.read(updateCheckProvider.future);
    if (update == null || !update.isUpdateAvailable) return;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => UpdateDialog(update: update),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final darkTheme = NamizoTheme.darkTheme(fontFamily: AppFontFamily.satoshi);

    return MaterialApp.router(
      title: 'Namizo',
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
