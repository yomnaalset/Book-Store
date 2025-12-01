import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/translations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/theme_service.dart' as theme_service;
import '../../../core/services/auth_service.dart';
import 'location_management_screen.dart';
import '../../../features/delivery_manager/providers/delivery_status_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/profile/providers/language_preference_provider.dart';
import '../../../features/profile/providers/user_settings_provider.dart';
import '../../../routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final statusProvider = Provider.of<DeliveryStatusProvider>(
      context,
      listen: false,
    );
    final languageProvider = Provider.of<LanguagePreferenceProvider>(
      context,
      listen: false,
    );
    final userSettingsProvider = Provider.of<UserSettingsProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await statusProvider.loadCurrentStatus();
    await languageProvider.loadLanguageOptions();

    // Load user settings if we have a token
    if (authProvider.token != null) {
      await userSettingsProvider.loadSettingsWithToken(authProvider.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppTranslations.t(context, 'settings')),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Consumer2<DeliveryStatusProvider, AuthProvider>(
        builder: (context, statusProvider, authProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                _buildProfileSection(authProvider),
                const SizedBox(height: 24),

                // Notification Settings
                _buildNotificationSection(statusProvider),
                const SizedBox(height: 24),

                // App Settings
                _buildAppSettingsSection(),
                const SizedBox(height: 24),

                // Account Actions
                _buildAccountActionsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSection(AuthProvider authProvider) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.deliveryProfile);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTranslations.t(context, 'profile'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${authProvider.user?.firstName ?? ''} ${authProvider.user?.lastName ?? ''}'
                                  .trim()
                                  .isEmpty
                              ? 'Delivery Manager'
                              : '${authProvider.user?.firstName ?? ''} ${authProvider.user?.lastName ?? ''}'
                                    .trim(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authProvider.user?.email ?? 'delivery@manager.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Delivery Manager',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSection(DeliveryStatusProvider statusProvider) {
    final theme = Theme.of(context);
    return Consumer<UserSettingsProvider>(
      builder: (context, userSettings, child) {
        return Card(
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.t(context, 'notifications'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildNotificationItem(
                  'New Task Assignments',
                  'Get notified when new tasks are assigned to you',
                  userSettings.orderUpdates,
                  (value) async {
                    await userSettings.updateNotificationSettings(
                      orderUpdates: value,
                    );
                    if (mounted) {
                      _showSettingsSavedMessage();
                    }
                  },
                ),
                _buildNotificationItem(
                  'Task Updates',
                  'Get notified about task status changes',
                  userSettings.deliveryUpdates,
                  (value) async {
                    await userSettings.updateNotificationSettings(
                      deliveryUpdates: value,
                    );
                    if (mounted) {
                      _showSettingsSavedMessage();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    final theme = Theme.of(context);
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.t(context, 'app_settings'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<LanguagePreferenceProvider>(
              builder: (context, languageProvider, child) {
                return _buildSettingsItem(
                  Icons.language,
                  'Language',
                  languageProvider.currentLanguageDisplayName,
                  () => _showLanguageDialog(languageProvider),
                );
              },
            ),
            Consumer<theme_service.ThemeService>(
              builder: (context, themeService, child) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.dark_mode,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Dark Mode'),
                    subtitle: Text(
                      themeService.isDarkMode ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Switch(
                      value: themeService.isDarkMode,
                      onChanged: (value) async {
                        await themeService.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
            _buildSettingsItem(
              Icons.my_location,
              'Manage Location',
              'Set your delivery location',
              () => _navigateToLocationManagement(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildAccountActionsSection() {
    final theme = Theme.of(context);
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.t(context, 'account'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionItem(Icons.lock, 'Change Password', () {
              Navigator.pushNamed(context, '/change-password');
            }),
            _buildActionItem(Icons.logout, 'Sign Out', () {
              _showLogoutDialog(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    // Make Sign Out icon red
    final iconColor = title == 'Sign Out'
        ? AppColors.error
        : theme.colorScheme.primary;

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showSettingsSavedMessage() {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Settings saved successfully'),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Language dialog
  void _showLanguageDialog(LanguagePreferenceProvider languageProvider) {
    // Define available languages
    final availableLanguages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'ar', 'name': 'العربية'},
    ];

    // Get current language or default to English
    final currentLanguage = languageProvider.currentLanguage ?? 'en';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Language'),
        content: RadioGroup<String>(
          groupValue: currentLanguage,
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

                final success = await languageProvider.updateLanguagePreference(
                  token,
                  value,
                );

                if (success && mounted) {
                  if (mounted) {
                    navigator.pop();
                    final languageName = availableLanguages.firstWhere(
                      (lang) => lang['code'] == value,
                    )['name'];
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Language changed to $languageName'),
                        backgroundColor: AppColors.success,
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
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } else {
                final navigator = Navigator.of(context);
                // Update local language preference even without token
                final translationsProvider = Provider.of<TranslationsProvider>(
                  context,
                  listen: false,
                );
                await translationsProvider.changeLocale(Locale(value));
                if (mounted) {
                  navigator.pop();
                }
              }
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableLanguages.map((language) {
              final languageCode = language['code'] as String;
              final languageName = language['name'] as String;

              return RadioListTile<String>(
                title: Text(languageName),
                subtitle: Text(languageCode.toUpperCase()),
                value: languageCode,
              );
            }).toList(),
          ),
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

  // Navigate to location management
  void _navigateToLocationManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationManagementScreen()),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Sign Out',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      // Clear all provider tokens
      if (context.mounted) {
        AuthService.clearProvidersTokens(context);

        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
