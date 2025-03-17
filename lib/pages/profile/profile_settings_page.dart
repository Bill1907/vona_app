import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/supabase/profile_service.dart';
// import '../../core/theme/theme_service.dart';
import 'account_details_page.dart';
import '../../pages/settings/privacy_policy_page.dart';
import '../../pages/settings/language_settings_page.dart';
import '../../core/language/app_localizations.dart';
import '../../core/language/extensions.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAppVersion();
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
        // 에러 메시지를 다음 프레임에서 표시
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('failedToLoadProfile'))),
          );
        });
      }
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = '1.0.0'; // 기본 버전
        });
        debugPrint('Failed to load app version: $e');
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
        title: Text(
          context.tr('logout'),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          context.tr('logoutConfirmation'),
          style: const TextStyle(
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
            child: Text(
              context.tr('logout'),
              style: const TextStyle(
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr('deleteAccount'),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          context.tr('deleteAccountConfirmation'),
          style: const TextStyle(
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement account deletion
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              context.tr('delete'),
              style: const TextStyle(
                fontFamily: 'Poppins',
              ),
            ),
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
        title: Text(
          context.tr('profile'),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: Color(0xFFffffff),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              _buildSectionTitle(context.tr('account')),
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
                title: Text(
                  _profile?['username'] ?? context.tr('user'),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  AuthService.currentUserEmail ?? context.tr('noEmail'),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _navigateToAccountDetails,
              ),
              const Divider(),

              // Etc Section
              _buildSectionTitle(context.tr('others')),
              // Dark Mode toggle commented out - will be implemented in future version
              // _buildSettingsTile(
              //   title: 'Dark Mode',
              //   trailing: Switch(
              //     value: context.watch<ThemeService>().isDarkMode,
              //     onChanged: (value) {
              //       context.read<ThemeService>().toggleTheme();
              //     },
              //   ),
              //   showChevron: false,
              // ),
              _buildSettingsTile(
                title: context.tr('appVersion'),
                trailing: Text(
                  'v$_appVersion',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                ),
                showChevron: false,
              ),
              _buildSettingsTile(
                title: context.tr('privacyPolicy'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              // _buildSettingsTile(
              //   title: 'Terms of Service',
              //   onTap: () {},
              // ),
              // Language Settings
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.tr('language')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, '/settings/language');
                },
              ),
              const Divider(),
              _buildSettingsTile(
                title: context.tr('logout'),
                onTap: _showLogoutDialog,
              ),
              _buildSettingsTile(
                title: context.tr('deleteAccount'),
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
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE2E2E2),
          fontFamily: 'Poppins',
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    Widget? trailing,
    Color? titleColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing:
          trailing ?? (showChevron ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
