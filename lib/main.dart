import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:namizo/core/cache/cache_service.dart';
import 'package:namizo/models/cache_entry.dart';
import 'package:namizo/models/new_episode.dart';
import 'package:namizo/models/watchlist_item.dart';
import 'package:namizo/providers/services.dart';
import 'package:namizo/providers/settings.dart';
import 'package:namizo/routes/routes.dart';
import 'package:namizo/services/episodes.dart';
import 'package:namizo/services/watchlist.dart';
import 'package:namizo/theme/font_family.dart';
import 'package:namizo/theme/theme.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
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

class NamizoApp extends ConsumerWidget {
  const NamizoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
