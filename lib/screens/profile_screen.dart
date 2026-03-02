import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, List, Map, Timer, Navigator, Page, Radius;
import 'package:namizo/core/theme.dart';
import 'package:namizo/providers/service_providers.dart';
import 'package:namizo/providers/watchlist_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final tmdbService = ref.watch(tmdbServiceProvider);

    return Scaffold(
      backgroundColor: NamizoTheme.netflixBlack,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        backgroundColor: NamizoTheme.netflixBlack,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0x337C73FF),
                  child: UserCircle(color: Color(0xFFB9B0FF), width: 22, height: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Namizo User',
                        style: TextStyle(
                          color: NamizoTheme.netflixWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your watchlist and preferences',
                        style: TextStyle(
                          color: NamizoTheme.netflixLightGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const BookmarkBook(color: Color(0xFFB9B0FF), width: 18, height: 18),
              const SizedBox(width: 8),
              Text(
                'My Watchlist (${watchlist.length})',
                style: const TextStyle(
                  color: NamizoTheme.netflixWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (watchlist.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: const Column(
                children: [
                  const Bookmark(color: NamizoTheme.netflixGrey, width: 38, height: 38),
                  SizedBox(height: 10),
                  Text(
                    'Your watchlist is empty',
                    style: TextStyle(color: NamizoTheme.netflixWhite),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add anime from details page to see them here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NamizoTheme.netflixGrey, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.62,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: watchlist.length,
              itemBuilder: (context, index) {
                final item = watchlist[index];
                final posterUrl = tmdbService.getPosterUrl(item.posterPath);

                return InkWell(
                  onTap: () => context.push('/media/${item.id}?type=${item.mediaType}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.posterPath != null
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: const Color(0x29222A3C),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF7C73FF),
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: const Color(0x29222A3C),
                                    child: const Center(
                                      child: MediaImageXmark(
                                        color: NamizoTheme.netflixGrey,
                                        width: 20,
                                        height: 20,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0x29222A3C),
                                  child: const Center(
                                    child: MediaVideo(
                                      color: NamizoTheme.netflixGrey,
                                      width: 20,
                                      height: 20,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NamizoTheme.netflixWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: const Color(0x1FFFFFFF),
            leading: const Settings(color: Color(0xFFB9B0FF), width: 22, height: 22),
            title: const Text(
              'Settings',
              style: TextStyle(color: NamizoTheme.netflixWhite),
            ),
            trailing: const NavArrowRight(color: NamizoTheme.netflixGrey, width: 18, height: 18),
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}
