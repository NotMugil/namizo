import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguagePreferences {
  final bool showAnime;

  const LanguagePreferences({this.showAnime = true});

  LanguagePreferences copyWith({bool? showAnime}) {
    return LanguagePreferences(showAnime: showAnime ?? this.showAnime);
  }
}

class LanguagePreferencesNotifier extends StateNotifier<LanguagePreferences> {
  LanguagePreferencesNotifier() : super(const LanguagePreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final showAnime = prefs.getBool('showAnime') ?? true;
    state = LanguagePreferences(showAnime: showAnime);
  }

  Future<void> toggleAnime(bool value) async {
    state = state.copyWith(showAnime: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showAnime', value);
  }
}

final languagePreferencesProvider =
    StateNotifierProvider<LanguagePreferencesNotifier, LanguagePreferences>(
      (ref) => LanguagePreferencesNotifier(),
    );
