import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.spacingXL),

                // Header
                _buildHeader(l10n),

                const SizedBox(height: AppDimensions.spacingXL),

                if (!_emailSent) ...[
                  // Email Form
                  _buildEmailForm(l10n),

                  const SizedBox(height: AppDimensions.spacingL),

                  // Send Button
                  _buildSendButton(l10n),
                ] else ...[
                  // Success Message
                  _buildSuccessMessage(l10n),

                  const SizedBox(height: AppDimensions.spacingL),

                  // Back to Login Button
                  _buildBackToLoginButton(l10n),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.lock_reset_outlined,
            color: theme.colorScheme.primary,
            size: 36,
          ),
        ),

        const SizedBox(height: AppDimensions.spacingL),

        // Title
        Text(
          _emailSent ? 'Check Your Email' : 'Forgot Password?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppDimensions.spacingS),

        // Description
        Text(
          _emailSent
              ? 'We\'ve sent a password reset link to your email address.'
              : 'Enter your email address and we\'ll send you a link to reset your password.',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n) {
    return CustomTextField(
      label: 'Email',
      hint: l10n.emailHint,
      controller: _emailController,
      type: TextFieldType.email,
      validator: Validators.email,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      prefixIcon: const Icon(Icons.email_outlined),
    );
  }

  Widget _buildSendButton(AppLocalizations l10n) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint(
          'DEBUG: Building send button - isLoading: ${authProvider.isLoading}',
        );
        return CustomButton(
          text: 'Send Reset Link',
          onPressed: authProvider.isLoading
              ? null
              : () {
                  debugPrint(
                    'DEBUG: Button pressed - calling _handleSendResetLink',
                  );
                  _handleSendResetLink();
                },
          type: ButtonType.primary,
          size: ButtonSize.large,
          isFullWidth: true,
          isLoading: authProvider.isLoading,
        );
      },
    );
  }

  Widget _buildSuccessMessage(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 26),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 76),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 48),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            'Password Reset Link Sent!',
            style: TextStyle(
              fontSize: AppDimensions.fontSizeL,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            'Please check your email and follow the instructions to reset your password.',
            style: TextStyle(
              fontSize: AppDimensions.fontSizeM,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBackToLoginButton(AppLocalizations l10n) {
    return CustomButton(
      text: 'Back to Login',
      onPressed: () {
        Navigator.pop(context);
      },
      type: ButtonType.outline,
      size: ButtonSize.large,
      isFullWidth: true,
    );
  }

  Future<void> _handleSendResetLink() async {
    debugPrint('DEBUG: _handleSendResetLink called');
    debugPrint('DEBUG: Form key current state: ${_formKey.currentState}');

    if (!_formKey.currentState!.validate()) {
      debugPrint('DEBUG: Form validation failed');
      return;
    }

    debugPrint('DEBUG: Form validation passed');
    debugPrint('DEBUG: Forgot password button clicked');
    debugPrint('DEBUG: Email: ${_emailController.text.trim()}');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    debugPrint('DEBUG: Calling authProvider.forgotPassword...');
    final success = await authProvider.forgotPassword(
      _emailController.text.trim(),
    );

    debugPrint('DEBUG: forgotPassword result: $success');
    debugPrint('DEBUG: Error message: ${authProvider.errorMessage}');

    if (mounted) {
      if (success) {
        debugPrint('DEBUG: Success - showing success message');
        setState(() {
          _emailSent = true;
        });
      } else {
        debugPrint('DEBUG: Failed - showing error message');
        _showErrorSnackBar(
          authProvider.errorMessage ?? 'Failed to send reset link',
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.error,
      ),
    );
  }
}
