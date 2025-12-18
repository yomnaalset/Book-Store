import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize any required data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  void _initializeScreen() {
    final theme = Theme.of(context);
    // Check if user is authenticated
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) {
      // Handle case where user is not authenticated
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseLogInToChangePassword),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      Navigator.pop(context);
      return;
    }
    // No need to load user profile data for password change
  }

  // Validate password strength
  bool _isPasswordStrong(String password) {
    if (password.length < 8) {
      return false;
    }
    // ignore: deprecated_member_use
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return false;
    }
    // ignore: deprecated_member_use
    if (!password.contains(RegExp(r'[a-z]'))) {
      return false;
    }
    // ignore: deprecated_member_use
    if (!password.contains(RegExp(r'[0-9]'))) {
      return false;
    }
    // ignore: deprecated_member_use
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).changePasswordTitle),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: AppDimensions.spacingM),
                        Text(
                          AppLocalizations.of(context).changeYourPassword,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingS),
                        Text(
                          AppLocalizations.of(context).enterCurrentAndNewPassword,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Current Password Field
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return CustomTextField(
                        controller: _currentPasswordController,
                        label: localizations.currentPasswordLabel,
                        hint: localizations.currentPasswordHint,
                    obscureText: _obscureCurrentPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localizations.pleaseEnterCurrentPassword;
                          }
                          return null;
                        },
                      );
                    },
                  ),

                  const SizedBox(height: AppDimensions.spacingL),

                  // New Password Field
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return CustomTextField(
                        controller: _newPasswordController,
                        label: localizations.newPasswordLabel,
                        hint: localizations.newPasswordHint,
                    obscureText: _obscureNewPassword,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    onChanged: (value) {
                      // Trigger rebuild to update password requirements
                      setState(() {});
                    },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localizations.pleaseEnterNewPassword;
                          }
                          if (value.length < 8) {
                            return localizations.passwordTooShort;
                          }
                          if (!_isPasswordStrong(value)) {
                            return localizations.passwordTooWeak;
                          }
                          return null;
                        },
                      );
                    },
                  ),

                  const SizedBox(height: AppDimensions.spacingL),

                  // Confirm Password Field
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return CustomTextField(
                        controller: _confirmPasswordController,
                        label: localizations.confirmNewPasswordLabel,
                        hint: localizations.confirmNewPasswordHint,
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    onChanged: (value) {
                      // Trigger rebuild to update validation
                      setState(() {});
                    },
                        validator: (value) {
                          final localizations = AppLocalizations.of(context);
                          if (value == null || value.isEmpty) {
                            return localizations.pleaseConfirmNewPassword;
                          }
                          if (value != _newPasswordController.text) {
                            return localizations.passwordsDoNotMatch;
                          }
                          return null;
                        },
                      );
                    },
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Password Requirements
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.passwordRequirements,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacingS),
                                _buildRequirementItem(
                                  localizations.atLeast8Characters,
                                  _newPasswordController.text.length >= 8,
                                ),
                                _buildRequirementItem(
                                  localizations.containsUppercase,
                                  _newPasswordController.text.contains(
                                    RegExp(r'[A-Z]'), // ignore: deprecated_member_use
                                  ),
                                ),
                                _buildRequirementItem(
                                  localizations.containsLowercase,
                                  _newPasswordController.text.contains(
                                    RegExp(r'[a-z]'), // ignore: deprecated_member_use
                                  ),
                                ),
                                _buildRequirementItem(
                                  localizations.containsNumber,
                                  _newPasswordController.text.contains(
                                    RegExp(r'[0-9]'), // ignore: deprecated_member_use
                                  ),
                                ),
                                _buildRequirementItem(
                                  localizations.containsSpecial,
                                  _newPasswordController.text.contains(
                                    // ignore: deprecated_member_use
                                    RegExp(
                                      // ignore: deprecated_member_use
                                      r'[!@#$%^&*(),.?":{}|<>]',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return CustomButton(
                              text: localizations.cancel,
                              onPressed: () => Navigator.pop(context),
                              backgroundColor: theme.colorScheme.surface,
                              textColor: theme.colorScheme.onSurfaceVariant,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return CustomButton(
                              text: _isLoading
                                  ? localizations.loading
                                  : localizations.changePasswordTitle,
                              onPressed: _isLoading ? null : _handleChangePassword,
                              isLoading: _isLoading,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isValid) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXS),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isValid
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final theme = Theme.of(context);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      debugPrint('=== PASSWORD CHANGE DEBUG START ===');
      debugPrint('DEBUG: Starting password change process');
      debugPrint(
        'DEBUG: AuthProvider token: ${authProvider.token != null ? '${authProvider.token!.substring(0, 20)}...' : 'null'}',
      );
      debugPrint(
        'DEBUG: Current password length: ${_currentPasswordController.text.length}',
      );
      debugPrint(
        'DEBUG: New password length: ${_newPasswordController.text.length}',
      );
      debugPrint(
        'DEBUG: Confirm password length: ${_confirmPasswordController.text.length}',
      );

      if (authProvider.token == null) {
        final localizations = AppLocalizations.of(context);
        throw Exception(localizations.noAuthenticationToken);
      }

      // Test connectivity first
      debugPrint('DEBUG: Testing connectivity to backend...');
      debugPrint('DEBUG: About to call testConnectivity()...');
      final connectivityTest = await profileProvider.testConnectivity();
      debugPrint('DEBUG: Connectivity test result: $connectivityTest');

      if (!connectivityTest) {
        throw Exception(
          'Cannot connect to backend server. Please check your network connection.',
        );
      }

      debugPrint('DEBUG: Calling profileProvider.changePassword...');
      final success = await profileProvider.changePassword(
        token: authProvider.token!,
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
      );
      debugPrint('DEBUG: Password change result: $success');
      debugPrint('=== PASSWORD CHANGE DEBUG END ===');

      if (mounted) {
        if (success) {
          // Clear form fields on success
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();

          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.passwordChangedSuccessfully),
              backgroundColor: theme.colorScheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );

          // Navigate back after a short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                profileProvider.errorMessage ??
                    localizations.failedToChangePassword,
              ),
              backgroundColor: theme.colorScheme.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorOccurred}: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
