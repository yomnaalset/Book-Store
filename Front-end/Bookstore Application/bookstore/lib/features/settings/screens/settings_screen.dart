import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/theme_service.dart' as theme;
import '../../../core/translations.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/ip_address_service.dart';
import '../../../core/services/api_config.dart';
import '../../../core/widgets/common/custom_text_field.dart';

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
  final TextEditingController _ipAddressController = TextEditingController();
  String? _ipAddressError;

  @override
  void initState() {
    super.initState();
    // Load all settings data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllSettingsData();
      _loadIpAddress();
    });
  }

  @override
  void dispose() {
    _ipAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadIpAddress() async {
    final ip = await IpAddressService.getIpAddress();
    if (mounted) {
      setState(() {
        _ipAddressController.text = ip;
      });
    }
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
      // Note: loadLanguageOptions() now handles syncing internally
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

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppTranslations.t(context, 'settings'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
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
          _buildServerIpSection(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildSupportSection(),
          const SizedBox(height: AppDimensions.spacingL),
          _buildAccountActionsSection(),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    final localizations = AppLocalizations.of(context);
    return _buildSection(
      title: localizations.account,
      icon: Icons.person_outline,
      children: [
        _buildListTile(
          icon: Icons.lock_outline,
          title: localizations.changePassword,
          subtitle: localizations.updateYourPassword,
          onTap: () => Navigator.pushNamed(context, '/change-password'),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection() {
    return Consumer<theme.ThemeService>(
      builder: (context, themeService, child) {
        final localizations = AppLocalizations.of(context);
        debugPrint(
          '_buildAppearanceSection rebuilding - isDarkMode: ${themeService.isDarkMode}',
        );
        return _buildSection(
          title: localizations.appearance,
          icon: Icons.palette_outlined,
          children: [
            _buildListTile(
              icon: Icons.dark_mode_outlined,
              title: localizations.darkMode,
              subtitle: themeService.isDarkMode
                  ? localizations.enabled
                  : localizations.disabled,
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
                  final localizations = AppLocalizations.of(context);

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
                          value
                              ? localizations.darkModeEnabled
                              : localizations.lightModeEnabled,
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
        final localizations = AppLocalizations.of(context);
        return _buildSection(
          title: localizations.language,
          icon: Icons.language_outlined,
          children: [
            _buildListTile(
              icon: Icons.translate,
              title: localizations.appLanguage,
              subtitle: _getLocalizedLanguageName(
                languageProvider.currentLanguage ??
                    translationsProvider.currentLocale.languageCode,
                localizations,
              ),
              onTap: () =>
                  _showLanguageDialog(languageProvider, translationsProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreferencesSection() {
    final localizations = AppLocalizations.of(context);
    return _buildSection(
      title: localizations.preferences,
      icon: Icons.settings_outlined,
      children: [
        _buildListTile(
          icon: Icons.notifications_outlined,
          title: localizations.notificationSettings,
          subtitle: localizations.manageYourNotificationPreferences,
          onTap: () => Navigator.pushNamed(context, '/notification-settings'),
        ),
        // Privacy Settings removed as per user request
      ],
    );
  }

  Widget _buildServerIpSection() {
    return _buildSection(
      title: 'Server IP Address',
      icon: Icons.dns_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                label: 'IP Address',
                hint: '192.168.1.5',
                controller: _ipAddressController,
                type: TextFieldType.text,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _ipAddressError = null;
                  });
                },
                errorText: _ipAddressError,
              ),
              const SizedBox(height: AppDimensions.spacingM),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveIpAddress,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveIpAddress() async {
    final ipAddress = _ipAddressController.text.trim();

    // Validate IP address
    if (ipAddress.isEmpty) {
      setState(() {
        _ipAddressError = 'IP address cannot be empty';
      });
      return;
    }

    if (!IpAddressService.isValidIpAddress(ipAddress)) {
      setState(() {
        _ipAddressError = 'Invalid IP address';
      });
      return;
    }

    // Store context-dependent values before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    // Save IP address
    final success = await IpAddressService.saveIpAddress(ipAddress);

    if (!mounted) return;

    if (success) {
      // Refresh API config
      await ApiConfig.refreshBaseUrl();

      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('IP Address saved successfully'),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to save IP address'),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildSupportSection() {
    final localizations = AppLocalizations.of(context);
    return _buildSection(
      title: localizations.supportLabel,
      icon: Icons.help_outline,
      children: [
        // Help & Support removed as per user request
        _buildListTile(
          icon: Icons.info_outline,
          title: localizations.aboutLabel,
          subtitle: localizations.appVersionAndInformation,
          onTap: _showAboutDialog,
        ),
      ],
    );
  }

  Widget _buildAccountActionsSection() {
    final localizations = AppLocalizations.of(context);
    return _buildSection(
      title: localizations.accountActions,
      icon: Icons.account_circle_outlined,
      children: [
        _buildListTile(
          icon: Icons.logout,
          title: localizations.signOut,
          subtitle: localizations.signOutSubtitle,
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
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.about),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.bookstoreApp),
            const SizedBox(height: 8),
            Text(localizations.appVersion),
            const SizedBox(height: 8),
            Text(localizations.appDescription),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.signOut),
        content: Text(localizations.signOutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(localizations.signOut),
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

  String _getLocalizedLanguageName(
    String languageCode,
    AppLocalizations localizations,
  ) {
    switch (languageCode) {
      case 'en':
        return localizations.englishLanguage;
      case 'ar':
        return localizations.arabicLanguage;
      default:
        return languageCode;
    }
  }

  void _showLanguageDialog(
    LanguagePreferenceProvider languageProvider,
    TranslationsProvider translationsProvider,
  ) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.chooseLanguage),
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
                    final localizations = AppLocalizations.of(context);

                    final success = await languageProvider
                        .updateLanguagePreference(token, value);

                    if (success && mounted && context.mounted) {
                      navigator.pop();
                      if (mounted && context.mounted) {
                        try {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${localizations.languageChanged} ${languageProvider.availableLanguages.firstWhere((lang) => lang['code'] == value)['name']}',
                              ),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          );
                        } catch (_) {
                          // Widget disposed, ignore
                        }
                      }
                    } else if (mounted && context.mounted) {
                      try {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              languageProvider.errorMessage ??
                                  localizations.failedToChangeLanguage,
                            ),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      } catch (_) {
                        // Widget disposed, ignore
                      }
                    }
                  } else {
                    final navigator = Navigator.of(context);
                    // Update local language preference even without token
                    await translationsProvider.changeLocale(Locale(value));
                    // Sync the language provider with the new locale
                    languageProvider.syncWithTranslationsProvider();
                    if (mounted && context.mounted) {
                      navigator.pop();
                    }
                  }
                }
              },
              child: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: languageProvider.availableLanguages.map((
                      language,
                    ) {
                      final languageCode = language['code'] as String;
                      // Use localized language names
                      String languageName;
                      switch (languageCode) {
                        case 'en':
                          languageName = localizations.englishLanguage;
                          break;
                        case 'ar':
                          languageName = localizations.arabicLanguage;
                          break;
                        default:
                          languageName = language['name'] as String;
                      }

                      return RadioListTile<String>(
                        title: Text(languageName),
                        subtitle: Text(languageCode.toUpperCase()),
                        value: languageCode,
                      );
                    }).toList(),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ],
      ),
    );
  }
}
