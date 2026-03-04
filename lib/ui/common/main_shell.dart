import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:namizo/theme/theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0F14),
          border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
          backgroundColor: NamizoTheme.netflixBlack,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: NamizoTheme.netflixRed,
          unselectedItemColor: NamizoTheme.netflixGrey,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIconsRegular.house, color: NamizoTheme.netflixGrey, size: 22),
              activeIcon: PhosphorIcon(PhosphorIconsFill.house, color: NamizoTheme.netflixRed, size: 22),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIconsRegular.magnifyingGlass, color: NamizoTheme.netflixGrey, size: 22),
              activeIcon: PhosphorIcon(PhosphorIconsFill.magnifyingGlass, color: NamizoTheme.netflixRed, size: 22),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIconsRegular.calendarBlank, color: NamizoTheme.netflixGrey, size: 22),
              activeIcon: PhosphorIcon(PhosphorIconsFill.calendarCheck, color: NamizoTheme.netflixRed, size: 22),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIconsRegular.userCircle, color: NamizoTheme.netflixGrey, size: 22),
              activeIcon: PhosphorIcon(PhosphorIconsFill.userCircle, color: NamizoTheme.netflixRed, size: 22),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
