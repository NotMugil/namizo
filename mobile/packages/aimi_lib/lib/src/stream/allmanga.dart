import 'allanime.dart';

/// Backward-compatible provider alias for the AllManga endpoint.
///
/// Reuses [AllAnime] implementation but exposes a different provider name
/// for user-facing selection and testing flows.
class AllManga extends AllAnime {
  @override
  String get name => 'AllManga';

  AllManga({super.client});
}
