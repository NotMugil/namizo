import 'package:flutter/material.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialFeedKey});

  final String? initialQuery;
  final String? initialFeedKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.magnifyingGlass,
                color: Colors.white.withValues(alpha: 0.3),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Discover',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming soon',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
