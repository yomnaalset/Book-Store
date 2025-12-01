import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/user_settings_provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Load settings when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    try {
      debugPrint('NotificationSettingsScreen: _loadSettings() called');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final settingsProvider = Provider.of<UserSettingsProvider>(
        context,
        listen: false,
      );

      debugPrint(
        'NotificationSettingsScreen: AuthProvider token: ${authProvider.token != null ? '${authProvider.token!.substring(0, 20)}...' : 'null'}',
      );
      debugPrint(
        'NotificationSettingsScreen: SettingsProvider: ${settingsProvider.runtimeType}',
      );

      if (authProvider.token != null) {
        debugPrint(
          'NotificationSettingsScreen: Loading settings with token...',
        );
        await settingsProvider.loadSettingsWithToken(authProvider.token!);
        debugPrint('NotificationSettingsScreen: Settings loaded successfully');
      } else {
        debugPrint(
          'NotificationSettingsScreen: No token available, loading from local storage',
        );
        await settingsProvider.loadAllSettings();
      }
    } catch (e) {
      debugPrint('NotificationSettingsScreen: Error loading settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          Consumer<UserSettingsProvider>(
            builder: (context, settingsProvider, child) {
              return TextButton(
                onPressed: () => _saveSettings(settingsProvider),
                child: const Text(
                  'Save',
                  style: TextStyle(color: AppColors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, UserSettingsProvider>(
        builder: (context, authProvider, settingsProvider, child) {
          if (authProvider.isLoading || settingsProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Preferences',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXS),
                            Text(
                              'Choose how you want to be notified about updates',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Notification Channels
                _buildSectionTitle('Notification Channels'),
                const SizedBox(height: AppDimensions.spacingM),
                _buildSwitchTile(
                  title: 'Email Notifications',
                  subtitle: 'Receive notifications via email',
                  value: settingsProvider.emailNotifications,
                  onChanged: (value) => settingsProvider
                      .updateNotificationSettings(emailNotifications: value),
                  icon: Icons.email_outlined,
                ),
                _buildSwitchTile(
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications on your device',
                  value: settingsProvider.pushNotifications,
                  onChanged: (value) => settingsProvider
                      .updateNotificationSettings(pushNotifications: value),
                  icon: Icons.phone_android_outlined,
                ),
                _buildSwitchTile(
                  title: 'SMS Notifications',
                  subtitle: 'Receive notifications via SMS',
                  value: settingsProvider.smsNotifications,
                  onChanged: (value) => settingsProvider
                      .updateNotificationSettings(smsNotifications: value),
                  icon: Icons.sms_outlined,
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Notification Types
                _buildSectionTitle('What to Notify Me About'),
                const SizedBox(height: AppDimensions.spacingM),
                _buildSwitchTile(
                  title: 'Order Updates',
                  subtitle: 'Updates about your orders and purchases',
                  value: settingsProvider.orderUpdates,
                  onChanged: (value) => settingsProvider
                      .updateNotificationSettings(orderUpdates: value),
                  icon: Icons.shopping_bag_outlined,
                ),
                // Book Availability removed as per user request
                _buildSwitchTile(
                  title: 'Borrow Reminders',
                  subtitle: 'Reminders about borrowed books and due dates',
                  value: settingsProvider.borrowReminders,
                  onChanged: (value) => settingsProvider
                      .updateNotificationSettings(borrowReminders: value),
                  icon: Icons.schedule_outlined,
                ),
                _buildSwitchTile(
                  title: 'Delivery Updates',
                  subtitle: 'Updates about book delivery status',
                  value: settingsProvider.deliveryUpdates,
                  onChanged: (value) => settingsProvider
                      .updateNotificationSettings(deliveryUpdates: value),
                  icon: Icons.local_shipping_outlined,
                ),

                // Marketing & Updates section removed as per user request
                const SizedBox(height: AppDimensions.spacingXL),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Reset to Default',
                        onPressed: () => _resetToDefault(settingsProvider),
                        backgroundColor: AppColors.background,
                        textColor: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: CustomButton(
                        text: 'Save Settings',
                        onPressed: () => _saveSettings(settingsProvider),
                        isLoading: settingsProvider.isLoading,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacingXL),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ),
    );
  }

  Future<void> _resetToDefault(UserSettingsProvider settingsProvider) async {
    await settingsProvider.resetNotificationSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings reset to default'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _saveSettings(UserSettingsProvider settingsProvider) async {
    try {
      debugPrint(
        'NotificationSettingsScreen: Save button pressed - forcing save to server...',
      );

      // Force save all current settings to the server
      await settingsProvider.forceSaveAllSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('NotificationSettingsScreen: Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
