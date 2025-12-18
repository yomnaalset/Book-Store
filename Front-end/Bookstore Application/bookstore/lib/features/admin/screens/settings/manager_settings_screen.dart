import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../admin/providers/manager_settings_provider.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/translations.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/language_preference_provider.dart';

class ManagerSettingsScreen extends StatefulWidget {
  const ManagerSettingsScreen({super.key});

  @override
  State<ManagerSettingsScreen> createState() => _ManagerSettingsScreenState();
}

class _ManagerSettingsScreenState extends State<ManagerSettingsScreen> {
  bool _isLoading = false;
  String _selectedLanguage = 'en';
  bool _isDarkMode = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;
  int _itemsPerPage = 10;
  bool _autoRefresh = true;
  int _refreshInterval = 30;
  ThemeService? _themeService;

  @override
  void initState() {
    super.initState();

    // Defer loading settings until after build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _themeService = context.read<ThemeService>();
      _themeService?.addListener(_onThemeChanged);
    });
  }

  @override
  void dispose() {
    // Remove theme listener using saved reference
    _themeService?.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted && _themeService != null) {
      setState(() {
        _isDarkMode = _themeService!.isDarkMode;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ManagerSettingsProvider>();
      final themeService = context.read<ThemeService>();
      final translationsProvider = context.read<TranslationsProvider>();

      await provider.loadSettings();

      // Get current language from TranslationsProvider (source of truth for UI)
      final currentLocale = translationsProvider.currentLocale;
      final currentLanguageCode = currentLocale.languageCode;

      // Update local state with loaded settings from provider
      setState(() {
        // Use TranslationsProvider's current locale as the source of truth
        _selectedLanguage = currentLanguageCode;
        _isDarkMode = themeService.isDarkMode; // Get from ThemeService instead
        _emailNotifications = provider.emailNotifications;
        _pushNotifications = provider.pushNotifications;
        _smsNotifications = provider.smsNotifications;
        _itemsPerPage = provider.itemsPerPage;
        _autoRefresh = provider.autoRefresh;
        _refreshInterval = provider.refreshInterval;
      });
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.errorLoadingSettings}: ${e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ManagerSettingsProvider>();
      final themeService = context.read<ThemeService>();

      // Update theme service first
      if (_isDarkMode) {
        await themeService.setThemeMode(ThemeMode.dark);
      } else {
        await themeService.setThemeMode(ThemeMode.light);
      }

      // Then update other settings
      await provider.updateSettings({
        'language': _selectedLanguage,
        'dark_mode': _isDarkMode,
        'email_notifications': _emailNotifications,
        'push_notifications': _pushNotifications,
        'sms_notifications': _smsNotifications,
        'items_per_page': _itemsPerPage,
        'auto_refresh': _autoRefresh,
        'refresh_interval': _refreshInterval,
      });

      if (mounted && context.mounted) {
        try {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.settingsSavedSuccessfully)),
          );
        } catch (_) {
          // Widget disposed, ignore
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        try {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.errorSavingSettings}: ${e.toString()}',
              ),
            ),
          );
        } catch (_) {
          // Widget disposed, ignore
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.resetToDefaults),
        content: Text(localizations.resetToDefaultsConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.reset),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final provider = context.read<ManagerSettingsProvider>();
        final themeService = context.read<ThemeService>();
        await provider.resetToDefaults();

        // Reset theme to light mode
        await themeService.setThemeMode(ThemeMode.light);

        // Reset local state to defaults
        setState(() {
          _selectedLanguage = 'en';
          _isDarkMode = false;
          _emailNotifications = true;
          _pushNotifications = true;
          _smsNotifications = false;
          _itemsPerPage = 10;
          _autoRefresh = true;
          _refreshInterval = 30;
        });

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.settingsResetToDefaults)),
          );
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.errorResettingSettings}: ${e.toString()}',
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.preferences),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _resetToDefaults,
            icon: const Icon(Icons.restore),
            tooltip: localizations.resetToDefault,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Settings
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildSectionCard(
                        title:
                            '${localizations.language} & ${localizations.appearance}',
                        icon: Icons.language,
                        children: [
                          Consumer<TranslationsProvider>(
                            builder: (context, translationsProvider, child) {
                              final localizations = AppLocalizations.of(
                                context,
                              );
                              return ListTile(
                                title: Text(localizations.language),
                                subtitle: Text(localizations.appLanguage),
                                trailing: DropdownButton<String>(
                                  value: _selectedLanguage,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'en',
                                      child: Text(
                                        localizations.englishLanguage,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'ar',
                                      child: Text(localizations.arabicLanguage),
                                    ),
                                  ],
                                  onChanged: (value) async {
                                    if (value != null &&
                                        value != _selectedLanguage) {
                                      setState(() {
                                        _selectedLanguage = value;
                                      });

                                      // Store context-dependent values before async gap
                                      final authProvider =
                                          Provider.of<AuthProvider>(
                                            context,
                                            listen: false,
                                          );
                                      final token = authProvider.token;
                                      final languageProvider = token != null
                                          ? Provider.of<
                                              LanguagePreferenceProvider
                                            >(context, listen: false)
                                          : null;
                                      final successMessage = value == 'en'
                                          ? localizations
                                                .languageChangedToEnglish
                                          : localizations
                                                .languageChangedToArabic;
                                      final scaffoldMessenger =
                                          ScaffoldMessenger.of(context);

                                      // Immediately update TranslationsProvider to trigger RTL/LTR switch
                                      final newLocale = value == 'ar'
                                          ? const Locale('ar', 'SA')
                                          : const Locale('en', 'US');
                                      await translationsProvider.changeLocale(
                                        newLocale,
                                      );

                                      // Check mounted before using context after async gap
                                      if (!mounted) return;

                                      // Optionally sync with server if user is authenticated
                                      if (token != null &&
                                          languageProvider != null) {
                                        try {
                                          await languageProvider
                                              .updateLanguagePreference(
                                                token,
                                                value,
                                              );
                                        } catch (e) {
                                          // Silently fail - local change still works
                                          debugPrint(
                                            'Failed to sync language to server: $e',
                                          );
                                        }
                                      }

                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(successMessage),
                                            backgroundColor: AppColors.success,
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                          Consumer<ThemeService>(
                            builder: (context, themeService, child) {
                              final theme = Theme.of(context);
                              return Container(
                                margin: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 8,
                                ),
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
                                  title: Text(localizations.darkMode),
                                  subtitle: Text(
                                    themeService.isDarkMode
                                        ? localizations.enabled
                                        : localizations.disabled,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Switch(
                                    value: themeService.isDarkMode,
                                    onChanged: (value) async {
                                      setState(() {
                                        _isDarkMode = value;
                                      });

                                      await themeService.setThemeMode(
                                        value
                                            ? ThemeMode.dark
                                            : ThemeMode.light,
                                      );
                                    },
                                    activeTrackColor: theme.colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notification Settings
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildSectionCard(
                        title: localizations.notificationSettings,
                        icon: Icons.notifications,
                        children: [
                          SwitchListTile(
                            title: Text(localizations.emailNotifications),
                            subtitle: Text(
                              localizations.receiveNotificationsViaEmail,
                            ),
                            value: _emailNotifications,
                            onChanged: (value) {
                              setState(() {
                                _emailNotifications = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            title: Text(localizations.pushNotifications),
                            subtitle: Text(
                              localizations.receivePushNotifications,
                            ),
                            value: _pushNotifications,
                            onChanged: (value) {
                              setState(() {
                                _pushNotifications = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            title: Text(localizations.smsNotifications),
                            subtitle: Text(
                              localizations.receiveNotificationsViaSms,
                            ),
                            value: _smsNotifications,
                            onChanged: (value) {
                              setState(() {
                                _smsNotifications = value;
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Display Settings
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildSectionCard(
                        title: localizations.settings,
                        icon: Icons.settings,
                        children: [
                          ListTile(
                            title: Text(localizations.itemsPerPage),
                            subtitle: Text(
                              localizations.numberOfItemsToDisplayPerPage,
                            ),
                            trailing: DropdownButton<int>(
                              value: _itemsPerPage,
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('5')),
                                DropdownMenuItem(value: 10, child: Text('10')),
                                DropdownMenuItem(value: 20, child: Text('20')),
                                DropdownMenuItem(value: 50, child: Text('50')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _itemsPerPage = value;
                                  });
                                }
                              },
                            ),
                          ),
                          SwitchListTile(
                            title: Text(localizations.autoRefresh),
                            subtitle: Text(
                              localizations.automaticallyRefreshData,
                            ),
                            value: _autoRefresh,
                            onChanged: (value) {
                              setState(() {
                                _autoRefresh = value;
                              });
                            },
                          ),
                          if (_autoRefresh) ...[
                            ListTile(
                              title: Text(localizations.refreshInterval),
                              subtitle: Text(
                                localizations.howOftenToRefreshData,
                              ),
                              trailing: DropdownButton<int>(
                                value: _refreshInterval,
                                items: const [
                                  DropdownMenuItem(
                                    value: 15,
                                    child: Text('15s'),
                                  ),
                                  DropdownMenuItem(
                                    value: 30,
                                    child: Text('30s'),
                                  ),
                                  DropdownMenuItem(
                                    value: 60,
                                    child: Text('1m'),
                                  ),
                                  DropdownMenuItem(
                                    value: 300,
                                    child: Text('5m'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _refreshInterval = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Account Actions
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildSectionCard(
                        title: localizations.accountActions,
                        icon: Icons.admin_panel_settings,
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.logout,
                              color: AppColors.error,
                            ),
                            title: Text(
                              localizations.signOut,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(localizations.signOutSubtitle),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () => _showLogoutDialog(context),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveSettings,
                          child: Text(localizations.saveChanges),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
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
            localizations.signOut,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            localizations.signOutConfirmation,
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
              child: Text(
                localizations.cancel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
              child: Text(
                localizations.signOut,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
