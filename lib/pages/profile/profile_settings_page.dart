import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/supabase/profile_service.dart';
import '../../core/theme/theme_service.dart';
import 'account_details_page.dart';
import 'package:vona_app/pages/settings/privacy_policy_page.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _loading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) throw 'User not found';

      final data = await ProfileService.getProfile(userId);
      if (mounted) {
        setState(() {
          _profile = data;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile')),
        );
      }
    }
  }

  void _navigateToAccountDetails() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountDetailsPage(),
      ),
    );

    if (result == true) {
      _loadProfile(); // Reload profile if updated
    }
  }

  void _navigateToSubscriptionDetails() {
    // TODO: Implement subscription details navigation
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement account deletion
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              _buildSectionTitle('Account'),
              ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: _profile?['avatar_url'] != null
                      ? NetworkImage(_profile!['avatar_url'])
                      : null,
                  child: _profile?['avatar_url'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(_profile?['username'] ?? 'User'),
                subtitle: Text(
                  AuthService.currentUserEmail ?? 'No email',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _navigateToAccountDetails,
              ),
              const Divider(),

              // // Subscribe Section
              // _buildSectionTitle('Subscription'),
              // ListTile(
              //   leading: const Icon(Icons.star),
              //   title: const Text('Current Plan'),
              //   subtitle:
              //       const Text('Free'), // TODO: Implement actual plan check
              //   trailing: const Icon(Icons.chevron_right),
              //   onTap: _navigateToSubscriptionDetails,
              // ),
              // const Divider(),

              // Etc Section
              _buildSectionTitle('Others'),
              _buildSettingsTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                trailing: Switch(
                  value: context.watch<ThemeService>().isDarkMode,
                  onChanged: (value) {
                    context.read<ThemeService>().toggleTheme();
                  },
                ),
                showChevron: false,
              ),
              // _buildSettingsTile(
              //   icon: Icons.announcement,
              //   title: 'Announcements',
              //   onTap: () {/* TODO: Navigate to notices */},
              // ),
              // _buildSettingsTile(
              //   icon: Icons.help,
              //   title: 'FAQ/Support',
              //   onTap: () {/* TODO: Navigate to FAQ */},
              // ),
              _buildSettingsTile(
                icon: Icons.info,
                title: 'App Version',
                trailing: const Text(
                  'v1.0.0',
                  style: TextStyle(color: Colors.grey),
                ),
                showChevron: false,
              ),
              _buildSettingsTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.description,
                title: 'Terms of Service',
                onTap: () {/* TODO: Navigate to terms */},
              ),
              const Divider(thickness: 1),
              _buildSettingsTile(
                icon: Icons.logout,
                title: 'Logout',
                onTap: _showLogoutDialog,
              ),
              _buildSettingsTile(
                icon: Icons.delete_forever,
                title: 'Delete Account',
                titleColor: Colors.red,
                onTap: _showDeleteAccountDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? titleColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      trailing:
          trailing ?? (showChevron ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
