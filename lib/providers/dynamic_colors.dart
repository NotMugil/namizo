import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:namizo/theme/theme.dart';

class DynamicColors {
  final Color dominant;
  final Color darkMuted;
  final Color darkVibrant;
  final Color lightVibrant;
  final Color lightMuted;
  final Color onSurface;

  const DynamicColors({
    required this.dominant,
    required this.darkMuted,
    required this.darkVibrant,
    required this.lightVibrant,
    required this.lightMuted,
    required this.onSurface,
  });

  static const fallback = DynamicColors(
    dominant: NamizoTheme.primary,
    darkMuted: NamizoTheme.background,
    darkVibrant: Color(0xFF8B3A00),
    lightVibrant: Color(0xFFFFC27A),
    lightMuted: NamizoTheme.surface,
    onSurface: NamizoTheme.textPrimary,
  );
}

/// Provider that extracts colors from an image URL
final dynamicColorsProvider = FutureProvider.family<DynamicColors, String?>((
  ref,
  imageUrl,
) async {
  if (imageUrl == null || imageUrl.isEmpty) {
    return DynamicColors.fallback;
  }

  try {
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(imageUrl),
      maximumColorCount: 20,
      timeout: const Duration(seconds: 5),
    );

    final dominant =
        paletteGenerator.dominantColor?.color ??
        paletteGenerator.vibrantColor?.color ??
        DynamicColors.fallback.dominant;

    final darkMuted =
        paletteGenerator.darkMutedColor?.color ?? _darken(dominant, 0.7);

    final darkVibrant =
        paletteGenerator.darkVibrantColor?.color ?? _darken(dominant, 0.5);

    final lightVibrant =
        paletteGenerator.lightVibrantColor?.color ?? _lighten(dominant, 0.3);

    final lightMuted =
        paletteGenerator.lightMutedColor?.color ?? _darken(dominant, 0.6);

    // Ensure text readability
    final onSurface =
        ThemeData.estimateBrightnessForColor(darkMuted) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return DynamicColors(
      dominant: dominant,
      darkMuted: darkMuted,
      darkVibrant: darkVibrant,
      lightVibrant: lightVibrant,
      lightMuted: lightMuted,
      onSurface: onSurface,
    );
  } catch (_) {
    return DynamicColors.fallback;
  }
});

Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness * (1 - amount)).clamp(0.0, 1.0))
      .toColor();
}

Color _lighten(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}
