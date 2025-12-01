import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/theme_service.dart' as theme;
import '../../../core/translations.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../profile/providers/language_preference_provider.dart';
import '../../profile/providers/user_settings_provider.dart';
import '../../profile/providers/profile_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Load all settings data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllSettingsData();
    });
  }

  Future<void> _loadAllSettingsData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguagePreferenceProvider>(
        context,
        listen: false,
      );
      final userSettingsProvider = Provider.of<UserSettingsProvider>(
        context,
        listen: false,
      );
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      debugPrint('SettingsScreen: Loading all settings data...');

      // Load language options
      await languageProvider.loadLanguageOptions();
      debugPrint('SettingsScreen: Language options loaded');

      // Load user settings if we have a token
      if (authProvider.token != null) {
        // Load current language preference
        await languageProvider.loadCurrentLanguagePreference(
          authProvider.token!,
        );
        debugPrint('SettingsScreen: Current language preference loaded');

        // Load profile data
        if (mounted) {
          await profileProvider.loadProfile(
            token: authProvider.token,
            context: context,
          );
          debugPrint('SettingsScreen: Profile data loaded');
        }

        // Load user settings
        await userSettingsProvider.loadSettingsWithToken(authProvider.token!);
        debugPrint('SettingsScreen: User settings loaded with token');
      } else {
        debugPrint('SettingsScreen: No token available for user settings');
      }

      debugPrint('SettingsScreen: All settings data loaded successfully');
    } catch (e) {
      debugPrint('SettingsScreen: Error loading settings data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBrightness = Theme.of(context).brightness;
    debugPrint('SettingsScreen build - Theme brightness: $currentBrightness');

    return Scaffold(
      appBar: AppBar(title: Text(AppTranslations.t(context, 'settings'))),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          _buildAccountSection(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildAppearanceSection(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildLanguageSection(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildPreferencesSection(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildSupportSection(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildAccountActionsSection(),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return _buildSection(
      title: 'Account',
      icon: Icons.person_outline,
      children: [
        _buildListTile(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Update your password',
          onTap: () => Navigator.pushNamed(context, '/change-password'),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return Consumer<theme.ThemeService>(
      builder: (context, themeService, child) {
        debugPrint(
          '_buildAppearanceSection rebuilding - isDarkMode: ${themeService.isDarkMode}',
        );
        return _buildSection(
          title: 'Appearance',
          icon: Icons.palette_outlined,
          children: [
            _buildListTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              subtitle: themeService.isDarkMode ? 'Enabled' : 'Disabled',
              trailing: Switch(
                value: themeService.isDarkMode,
                onChanged: (value) async {
                  debugPrint('=== DARK MODE SWITCH TOGGLED ===');
                  debugPrint('Switch toggled to: $value');
                  debugPrint(
                    'Current ThemeMode before change: ${themeService.themeMode}',
                  );
                  debugPrint('Current isDarkMode: ${themeService.isDarkMode}');

                  // Store context values before async operation
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final currentTheme = Theme.of(context);

                  await themeService.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );

                  debugPrint(
                    'Current ThemeMode after change: ${themeService.themeMode}',
                  );
                  debugPrint(
                    'Current isDarkMode after change: ${themeService.isDarkMode}',
                  );
                  debugPrint('=== END SWITCH TOGGLE ===');

                  // Show confirmation
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          value ? 'Dark mode enabled' : 'Light mode enabled',
                        ),
                        backgroundColor: currentTheme.colorScheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSection() {
    return Consumer2<LanguagePreferenceProvider, TranslationsProvider>(
      builder: (context, languageProvider, translationsProvider, child) {
        return _buildSection(
          title: 'Language',
          icon: Icons.language_outlined,
          children: [
            _buildListTile(
              icon: Icons.translate,
              title: 'App Language',
              subtitle: languageProvider.currentLanguageDisplayName,
              onTap: () =>
                  _showLanguageDialog(languageProvider, translationsProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreferencesSection() {
    return _buildSection(
      title: 'Preferences',
      icon: Icons.settings_outlined,
      children: [
        _buildListTile(
          icon: Icons.notifications_outlined,
          title: 'Notification Settings',
          subtitle: 'Manage your notification preferences',
          onTap: () => Navigator.pushNamed(context, '/notification-settings'),
        ),
        // Privacy Settings removed as per user request
      ],
    );
  }

  Widget _buildSupportSection() {
    return _buildSection(
      title: 'Support',
      icon: Icons.help_outline,
      children: [
        // Help & Support removed as per user request
        _buildListTile(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'App version and information',
          onTap: _showAboutDialog,
        ),
      ],
    );
  }

  Widget _buildAccountActionsSection() {
    return _buildSection(
      title: 'Account Actions',
      icon: Icons.account_circle_outlined,
      children: [
        _buildListTile(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          onTap: _showSignOutDialog,
          textColor: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.paddingM,
            bottom: AppDimensions.spacingM,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                title,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeM,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.w500,
          color: textColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: AppDimensions.fontSizeS,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookstore App'),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text(
              'A modern bookstore application for browsing, purchasing, and borrowing books.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _signOut() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _showLanguageDialog(
    LanguagePreferenceProvider languageProvider,
    TranslationsProvider translationsProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Language'),
        content: Consumer<LanguagePreferenceProvider>(
          builder: (context, languageProvider, child) {
            if (languageProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RadioGroup<String>(
              groupValue: languageProvider.currentLanguage,
              onChanged: (value) async {
                if (value != null) {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final token = authProvider.token;

                  if (token != null) {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final theme = Theme.of(context);

                    final success = await languageProvider
                        .updateLanguagePreference(token, value);

                    if (success && mounted) {
                      navigator.pop();
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Language changed to ${languageProvider.availableLanguages.firstWhere((lang) => lang['code'] == value)['name']}',
                            ),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      }
                    } else if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            languageProvider.errorMessage ??
                                'Failed to change language',
                          ),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  } else {
                    final navigator = Navigator.of(context);
                    // Update local language preference even without token
                    await translationsProvider.changeLocale(Locale(value));
                    if (mounted) {
                      navigator.pop();
                    }
                  }
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: languageProvider.availableLanguages.map((language) {
                  final languageCode = language['code'] as String;
                  final languageName = language['name'] as String;

                  return RadioListTile<String>(
                    title: Text(languageName),
                    subtitle: Text(languageCode.toUpperCase()),
                    value: languageCode,
                  );
                }).toList(),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
