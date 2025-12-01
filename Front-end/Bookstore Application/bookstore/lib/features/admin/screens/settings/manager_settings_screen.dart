import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../admin/providers/manager_settings_provider.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../auth/providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();

    // Listen to theme changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeService = context.read<ThemeService>();
      themeService.addListener(_onThemeChanged);
    });
  }

  @override
  void dispose() {
    // Remove theme listener
    final themeService = context.read<ThemeService>();
    themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      final themeService = context.read<ThemeService>();
      setState(() {
        _isDarkMode = themeService.isDarkMode;
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
      await provider.loadSettings();

      // Update local state with loaded settings from provider
      setState(() {
        _selectedLanguage = provider.language;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: ${e.toString()}')),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: ${e.toString()}')),
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

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings reset to defaults')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting settings: ${e.toString()}'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Settings'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _resetToDefaults,
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
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
                  _buildSectionCard(
                    title: 'Language & Display',
                    icon: Icons.language,
                    children: [
                      ListTile(
                        title: const Text('Language'),
                        subtitle: const Text('Select your preferred language'),
                        trailing: DropdownButton<String>(
                          value: _selectedLanguage,
                          items: const [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            DropdownMenuItem(
                              value: 'ar',
                              child: Text('العربية'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedLanguage = value;
                              });
                            }
                          },
                        ),
                      ),
                      Consumer<ThemeService>(
                        builder: (context, themeService, child) {
                          final theme = Theme.of(context);
                          return Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 8),
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
                                themeService.isDarkMode
                                    ? 'Enabled'
                                    : 'Disabled',
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
                                    value ? ThemeMode.dark : ThemeMode.light,
                                  );
                                },
                                activeTrackColor: theme.colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notification Settings
                  _buildSectionCard(
                    title: 'Notifications',
                    icon: Icons.notifications,
                    children: [
                      SwitchListTile(
                        title: const Text('Email Notifications'),
                        subtitle: const Text('Receive notifications via email'),
                        value: _emailNotifications,
                        onChanged: (value) {
                          setState(() {
                            _emailNotifications = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Receive push notifications'),
                        value: _pushNotifications,
                        onChanged: (value) {
                          setState(() {
                            _pushNotifications = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('SMS Notifications'),
                        subtitle: const Text('Receive notifications via SMS'),
                        value: _smsNotifications,
                        onChanged: (value) {
                          setState(() {
                            _smsNotifications = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Display Settings
                  _buildSectionCard(
                    title: 'Display & Performance',
                    icon: Icons.settings,
                    children: [
                      ListTile(
                        title: const Text('Items per Page'),
                        subtitle: const Text(
                          'Number of items to display per page',
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
                        title: const Text('Auto Refresh'),
                        subtitle: const Text('Automatically refresh data'),
                        value: _autoRefresh,
                        onChanged: (value) {
                          setState(() {
                            _autoRefresh = value;
                          });
                        },
                      ),
                      if (_autoRefresh) ...[
                        ListTile(
                          title: const Text('Refresh Interval'),
                          subtitle: const Text(
                            'How often to refresh data (seconds)',
                          ),
                          trailing: DropdownButton<int>(
                            value: _refreshInterval,
                            items: const [
                              DropdownMenuItem(value: 15, child: Text('15s')),
                              DropdownMenuItem(value: 30, child: Text('30s')),
                              DropdownMenuItem(value: 60, child: Text('1m')),
                              DropdownMenuItem(value: 300, child: Text('5m')),
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
                  ),
                  const SizedBox(height: 16),

                  // Account Actions
                  _buildSectionCard(
                    title: 'Account Actions',
                    icon: Icons.admin_panel_settings,
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.logout,
                          color: AppColors.error,
                        ),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text('Sign out of your account'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showLogoutDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      child: const Text('Save Settings'),
                    ),
                  ),
                ],
              ),
            ),
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
