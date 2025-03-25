import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dashboard/diary_dashboard_page.dart';
import 'diary/diary_list_page.dart';
import 'profile/profile_settings_page.dart';
import 'realtime/realtime_communication_page.dart';
import '../core/language/extensions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;
    final List<Widget> pages = [
      const DiaryDashboardPage(),
      if (userId != null) RealtimeCommunicationPage(userId: userId),
      const DiaryListPage(),
      const ProfileSettingsPage(),
    ];

    // Ensure _currentIndex is within valid range
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        height: 80,
        backgroundColor: Colors.black,
        indicatorColor: Colors.black,
        animationDuration: Duration.zero,
        onDestinationSelected: (index) {
          // Adjust index for non-logged in users
          final adjustedIndex = userId == null && index > 0 ? index - 1 : index;
          setState(() {
            _currentIndex = adjustedIndex;
          });
        },
        destinations: [
          NavigationDestination(
            icon: SvgPicture.asset(
              'assets/icons/house_icon.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
            selectedIcon: SvgPicture.asset(
              'assets/icons/house_icon.svg',
              width: 24,
              height: 24,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            label: context.tr('home'),
          ),
          if (userId != null)
            NavigationDestination(
              icon: SvgPicture.asset(
                'assets/icons/voice_icon.svg',
                width: 24,
                height: 24,
                colorFilter:
                    const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
              ),
              selectedIcon: SvgPicture.asset(
                'assets/icons/voice_icon.svg',
                width: 24,
                height: 24,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              label: context.tr('voice'),
            ),
          NavigationDestination(
            icon: SvgPicture.asset(
              'assets/icons/book_icon.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
            selectedIcon: SvgPicture.asset(
              'assets/icons/book_icon.svg',
              width: 24,
              height: 24,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            label: context.tr('journals'),
          ),
          NavigationDestination(
            icon: SvgPicture.asset(
              'assets/icons/user_icon.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
            selectedIcon: SvgPicture.asset(
              'assets/icons/user_icon.svg',
              width: 24,
              height: 24,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            label: context.tr('profile'),
          ),
        ],
      ),
    );
  }
}
