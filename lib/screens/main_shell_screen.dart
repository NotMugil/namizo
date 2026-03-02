import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text, List, Map, Timer, Navigator, Page, Radius;
import 'package:nivio/core/theme.dart';

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
          backgroundColor: NivioTheme.netflixBlack,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF9D96FF),
          unselectedItemColor: NivioTheme.netflixGrey,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: HomeSimple(color: NivioTheme.netflixGrey, width: 22, height: 22),
              activeIcon: HomeSimple(color: Color(0xFF9D96FF), width: 22, height: 22),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Search(color: NivioTheme.netflixGrey, width: 22, height: 22),
              activeIcon: Search(color: Color(0xFF9D96FF), width: 22, height: 22),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Calendar(color: NivioTheme.netflixGrey, width: 22, height: 22),
              activeIcon: CalendarCheck(color: Color(0xFF9D96FF), width: 22, height: 22),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: UserCircle(color: NivioTheme.netflixGrey, width: 22, height: 22),
              activeIcon: UserCircle(color: Color(0xFF9D96FF), width: 22, height: 22),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
