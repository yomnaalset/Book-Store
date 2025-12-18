import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
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
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.notificationSettingsTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          Consumer<UserSettingsProvider>(
            builder: (context, settingsProvider, child) {
              return TextButton(
                onPressed: () => _saveSettings(settingsProvider),
                child: Text(
                  localizations.save,
                  style: const TextStyle(color: AppColors.white),
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
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      localizations.notificationPreferences,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingXS,
                                    ),
                                    Text(
                                      localizations.chooseHowToBeNotified,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Notification Channels
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(localizations.notificationChannels),
                        const SizedBox(height: AppDimensions.spacingM),
                        _buildSwitchTile(
                          title: localizations.emailNotifications,
                          subtitle: localizations.receiveNotificationsViaEmail,
                          value: settingsProvider.emailNotifications,
                          onChanged: (value) =>
                              settingsProvider.updateNotificationSettings(
                                emailNotifications: value,
                              ),
                          icon: Icons.email_outlined,
                        ),
                        _buildSwitchTile(
                          title: localizations.pushNotifications,
                          subtitle: localizations.receivePushNotifications,
                          value: settingsProvider.pushNotifications,
                          onChanged: (value) =>
                              settingsProvider.updateNotificationSettings(
                                pushNotifications: value,
                              ),
                          icon: Icons.phone_android_outlined,
                        ),
                        _buildSwitchTile(
                          title: localizations.smsNotifications,
                          subtitle: localizations.receiveNotificationsViaSms,
                          value: settingsProvider.smsNotifications,
                          onChanged: (value) =>
                              settingsProvider.updateNotificationSettings(
                                smsNotifications: value,
                              ),
                          icon: Icons.sms_outlined,
                        ),
                        const SizedBox(height: AppDimensions.spacingXL),
                        // Notification Types
                        _buildSectionTitle(localizations.whatToNotifyMeAbout),
                        const SizedBox(height: AppDimensions.spacingM),
                        _buildSwitchTile(
                          title: localizations.orderUpdates,
                          subtitle: localizations.updatesAboutOrders,
                          value: settingsProvider.orderUpdates,
                          onChanged: (value) => settingsProvider
                              .updateNotificationSettings(orderUpdates: value),
                          icon: Icons.shopping_bag_outlined,
                        ),
                        // Book Availability removed as per user request
                        _buildSwitchTile(
                          title: localizations.borrowReminders,
                          subtitle: localizations.remindersAboutBorrowedBooks,
                          value: settingsProvider.borrowReminders,
                          onChanged: (value) =>
                              settingsProvider.updateNotificationSettings(
                                borrowReminders: value,
                              ),
                          icon: Icons.schedule_outlined,
                        ),
                        _buildSwitchTile(
                          title: localizations.deliveryUpdates,
                          subtitle: localizations.updatesAboutDeliveryStatus,
                          value: settingsProvider.deliveryUpdates,
                          onChanged: (value) =>
                              settingsProvider.updateNotificationSettings(
                                deliveryUpdates: value,
                              ),
                          icon: Icons.local_shipping_outlined,
                        ),
                      ],
                    );
                  },
                ),

                // Marketing & Updates section removed as per user request
                const SizedBox(height: AppDimensions.spacingXL),

                // Action Buttons
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: localizations.resetToDefault,
                            onPressed: () => _resetToDefault(settingsProvider),
                            backgroundColor: AppColors.background,
                            textColor: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Expanded(
                          child: CustomButton(
                            text: localizations.saveSettings,
                            onPressed: () => _saveSettings(settingsProvider),
                            isLoading: settingsProvider.isLoading,
                          ),
                        ),
                      ],
                    );
                  },
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
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.settingsResetToDefault),
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.notificationSettingsSaved),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('NotificationSettingsScreen: Error saving settings: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.errorSavingSettings}: ${e.toString()}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
