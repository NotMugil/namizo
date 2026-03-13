import 'dart:io';
import 'package:aimi_lib/aimi_lib.dart';

String? ask(String question) {
  print('\n$question');
  stdout.write('> ');
  return stdin.readLineSync()?.trim();
}

T? selectOption<T>(
  List<T> options, {
  required String prompt,
  required String Function(T) display,
}) {
  if (options.isEmpty) return null;

  print('\n$prompt');
  for (var i = 0; i < options.length; i++) {
    print('[$i] ${display(options[i])}');
  }

  final input = ask('Select an option (0-${options.length - 1}):');
  if (input == null) return null;

  final index = int.tryParse(input);
  if (index != null && index >= 0 && index < options.length) {
    return options[index];
  }

  print('Invalid selection.');
  return null;
}

void main() async {
  StreamProvider? provider;

  try {
    final animeDetails = await _searchMetadata();
    if (animeDetails == null) return;

    _printAnimeDetails(animeDetails);

    provider = _selectProvider();
    print('\nUsing provider: ${provider.name}');

    final streamAnime = await _findOnProvider(provider, animeDetails.title);
    if (streamAnime == null) return;

    final episode = await _selectEpisode(streamAnime);
    if (episode == null) return;

    await _playEpisode(episode, animeDetails.title, provider);
  } catch (e) {
    print('\nError: $e');
  } finally {
    _closeProvider(provider);
  }
}

Future<AnimeDetails?> _searchMetadata() async {
  final db = Kuroiru();
  final query = ask('Enter anime name to search:');
  if (query == null || query.isEmpty) return null;

  print('Searching Kuroiru...');
  final results = await db.search(query);

  if (results.isEmpty) {
    print('No results found.');
    return null;
  }

  final selection = selectOption(
    results,
    prompt: 'Found ${results.length} results:',
    display: (r) => '${r.title} (${r.type} - ${r.time})',
  );

  if (selection == null) return null;

  print('Fetching details for ${selection.title}...');
  return db.getDetails(selection.id);
}

void _printAnimeDetails(AnimeDetails anime) {
  print('\n--- Anime Details ---');
  print('Title:    ${anime.title}');
  print('Score:    ${anime.score ?? "N/A"}');
  print('Rating:   ${anime.rating ?? "N/A"}');
  print('Status:   ${anime.status ?? "N/A"}');
  print('Genres:   ${anime.genres?.join(', ') ?? "N/A"}');
  print('Synopsis: ${anime.description?.replaceAll('\n', ' ') ?? "N/A"}');
  print('---------------------');
}

StreamProvider _selectProvider() {
  final providers = [AllManga(), AnimePahe(), Anizone(), Anidap()];

  final selected = selectOption(
    providers,
    prompt: 'Select a stream provider:',
    display: (p) => p.name,
  );

  return selected ?? providers.first;
}

Future<StreamableAnime?> _findOnProvider(
  StreamProvider provider,
  String title,
) async {
  print('Searching "$title" in ${provider.name}...');
  final results = await provider.search(title);

  if (results.isEmpty) {
    print('No results found in ${provider.name}.');
    return null;
  }

  return selectOption(
    results,
    prompt: 'Found ${results.length} matches on ${provider.name}:',
    display: (a) => '${a.title} (${a.availableEpisodes ?? "?"} eps)',
  );
}

Future<Episode?> _selectEpisode(StreamableAnime anime) async {
  print('Fetching episodes for ${anime.title}...');
  final episodes = await anime.getEpisodes();

  if (episodes.isEmpty) {
    print('No episodes found.');
    return null;
  }

  episodes.sort((a, b) {
    final numA = double.tryParse(a.number);
    final numB = double.tryParse(b.number);
    if (numA != null && numB != null) return numA.compareTo(numB);
    return a.number.compareTo(b.number);
  });

  print('\nAvailable episodes: ${episodes.map((e) => e.number).join(', ')}');

  final epNum = ask('Enter episode number:');
  if (epNum == null) return null;

  try {
    return episodes.firstWhere((e) => e.number == epNum);
  } catch (_) {
    print('Episode not found.');
    return null;
  }
}

Future<void> _playEpisode(
  Episode episode,
  String animeTitle,
  StreamProvider provider,
) async {
  Map<String, dynamic>? options;
  if (provider is Anidap) {
    options = _selectAnidapOptions();
  }

  print('Fetching video sources...');
  final sources = await episode.getSources(options: options);

  if (sources.isEmpty) {
    print('No video sources found.');
    return;
  }

  final selectedSource = selectOption(
    sources,
    prompt: 'Select video quality:',
    display: (s) => '${s.quality} (${s.type})',
  );

  if (selectedSource == null) return;

  print('Launching player...');
  try {
    await Player.play(
      selectedSource,
      title: '$animeTitle - Episode ${episode.number}',
    );
  } catch (e) {
    print('Player launch failed: $e');
    print('Source URL: ${selectedSource.url}');
    if (selectedSource.headers != null && selectedSource.headers!.isNotEmpty) {
      print('Required headers: ${selectedSource.headers}');
    }
  }
}

Map<String, dynamic> _selectAnidapOptions() {
  final modes = ['sub', 'dub'];
  final hosts = ['yuki', 'kami', 'ozzy', 'nuri', 'dih', 'koto', 'mizu', 'pahe'];

  final selectedMode = selectOption(
    modes,
    prompt: 'Anidap mode:',
    display: (m) => m,
  );

  final selectedHost = selectOption(
    hosts,
    prompt: 'Anidap host:',
    display: (h) => h,
  );

  final mode = selectedMode ?? modes.first;
  final host = selectedHost ?? hosts.first;
  print('Using Anidap mode: $mode, host: $host');

  return {'mode': mode, 'host': host};
}

void _closeProvider(StreamProvider? provider) {
  if (provider is AllAnime) provider.close();
  if (provider is AnimePahe) provider.close();
  if (provider is Anizone) provider.close();
  if (provider is Anidap) provider.close();
}
