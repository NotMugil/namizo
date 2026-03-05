import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Displays the banner, avatar, and username at the top of the profile screen.
class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> viewer;

  const ProfileHeader({super.key, required this.viewer});

  @override
  Widget build(BuildContext context) {
    final name = (viewer['name'] ?? 'AniList User').toString();
    final bannerUrl = viewer['bannerImage']?.toString();
    final avatar = viewer['avatar'] as Map<String, dynamic>?;
    final avatarUrl =
        avatar?['large']?.toString() ?? avatar?['medium']?.toString();

    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bannerUrl != null && bannerUrl.isNotEmpty)
            CachedNetworkImage(imageUrl: bannerUrl, fit: BoxFit.cover)
          else
            Container(color: NamizoTheme.surface),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x70000000), Color(0xE6000000)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.go('/home'),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.caretLeft,
                        color: NamizoTheme.textPrimary,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/settings'),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.gear,
                        color: NamizoTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: NamizoTheme.surface,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const PhosphorIcon(
                          PhosphorIconsRegular.userCircle,
                          color: NamizoTheme.textPrimary,
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: NamizoTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
