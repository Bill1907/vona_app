import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard/diary_dashboard_page.dart';
import 'diary/diary_list_page.dart';
import 'profile/profile_settings_page.dart';
import 'realtime/realtime_communication_page.dart';

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
        onDestinationSelected: (index) {
          // Adjust index for non-logged in users
          final adjustedIndex = userId == null && index > 0 ? index - 1 : index;
          setState(() {
            _currentIndex = adjustedIndex;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          if (userId != null)
            const NavigationDestination(
              icon: Icon(Icons.graphic_eq),
              label: 'Realtime',
            ),
          const NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Journals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
