import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Simple custom icon for password reset - shows a key
class PasswordResetIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const PasswordResetIcon({super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PasswordResetIconPainter(iconColor)),
    );
  }
}

class _PasswordResetIconPainter extends CustomPainter {
  final Color color;

  _PasswordResetIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final keyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    // Key dimensions - improved proportions
    final keyHeadRadius = size.width * 0.22; // Slightly larger head
    final keyHeadCenterY = center.dy - size.width * 0.12;
    final keyShaftWidth = size.width * 0.1; // Narrower, more elegant shaft
    final keyShaftLength = size.width * 0.32;
    final keyBitWidth = size.width * 0.2; // Wider bit
    final keyBitHeight = size.width * 0.18; // Taller bit

    // Draw key head (round circle at top) with hole
    canvas.drawCircle(
      Offset(center.dx, keyHeadCenterY),
      keyHeadRadius,
      keyPaint,
    );

    // Draw hole in key head (like real keys)
    canvas.drawCircle(
      Offset(center.dx, keyHeadCenterY),
      keyHeadRadius * 0.4,
      holePaint,
    );

    // Draw key shaft (smooth rounded rectangle connecting head to bit)
    final shaftTop = keyHeadCenterY + keyHeadRadius;
    final shaftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, shaftTop + keyShaftLength * 0.5),
        width: keyShaftWidth,
        height: keyShaftLength,
      ),
      Radius.circular(size.width * 0.025),
    );
    canvas.drawRRect(shaftRect, keyPaint);

    // Draw key bit (the part that goes into lock - with refined notches)
    final bitTop = shaftTop + keyShaftLength;
    final bitPath = Path()
      // Start from left side of shaft
      ..moveTo(center.dx - keyShaftWidth * 0.5, bitTop)
      // Smooth transition to left edge of bit
      ..lineTo(center.dx - keyBitWidth * 0.5, bitTop)
      // Down to bottom left
      ..lineTo(center.dx - keyBitWidth * 0.5, bitTop + keyBitHeight)
      // Left notch (inward)
      ..lineTo(center.dx - keyBitWidth * 0.35, bitTop + keyBitHeight * 0.65)
      // Back out
      ..lineTo(center.dx - keyBitWidth * 0.35, bitTop + keyBitHeight)
      // Continue to center-left
      ..lineTo(center.dx - keyBitWidth * 0.15, bitTop + keyBitHeight)
      // Center notch (inward)
      ..lineTo(center.dx - keyBitWidth * 0.15, bitTop + keyBitHeight * 0.5)
      // Back out
      ..lineTo(center.dx - keyBitWidth * 0.15, bitTop + keyBitHeight)
      // Continue to center-right
      ..lineTo(center.dx + keyBitWidth * 0.15, bitTop + keyBitHeight)
      // Center-right notch (inward)
      ..lineTo(center.dx + keyBitWidth * 0.15, bitTop + keyBitHeight * 0.5)
      // Back out
      ..lineTo(center.dx + keyBitWidth * 0.15, bitTop + keyBitHeight)
      // Continue to right
      ..lineTo(center.dx + keyBitWidth * 0.35, bitTop + keyBitHeight)
      // Right notch (inward)
      ..lineTo(center.dx + keyBitWidth * 0.35, bitTop + keyBitHeight * 0.65)
      // Back out
      ..lineTo(center.dx + keyBitWidth * 0.5, bitTop + keyBitHeight)
      // Up to top right
      ..lineTo(center.dx + keyBitWidth * 0.5, bitTop)
      // Back to right side of shaft
      ..lineTo(center.dx + keyShaftWidth * 0.5, bitTop)
      // Close the path
      ..close();

    canvas.drawPath(bitPath, keyPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          l10n.forgotPasswordTitle,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // Header
                _buildHeader(l10n),

                const SizedBox(height: 32),

                if (!_emailSent) ...[
                  // Email Form Card
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email Form
                        _buildEmailForm(l10n),

                        const SizedBox(height: 24),

                        // Send Button
                        _buildSendButton(l10n),
                      ],
                    ),
                  ),
                ] else ...[
                  // Success Message
                  _buildSuccessMessage(l10n),

                  const SizedBox(height: 24),

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
        // Icon with solid blue gradient background and glow
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 102),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 4,
              ),
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 51),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: PasswordResetIcon(size: 48, color: Colors.white),
          ),
        ),

        const SizedBox(height: 24),

        // Title
        Text(
          _emailSent ? l10n.checkYourEmail : l10n.forgotPasswordQuestionTitle,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Description
        Text(
          _emailSent ? l10n.passwordResetLinkSent : l10n.enterEmailForReset,
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailForm(AppLocalizations l10n) {
    return CustomTextField(
      label: l10n.emailLabelLogin,
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
    final theme = Theme.of(context);
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint(
          'DEBUG: Building send button - isLoading: ${authProvider.isLoading}',
        );
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 77),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: CustomButton(
            text: l10n.sendResetLink,
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
          ),
        );
      },
    );
  }

  Widget _buildSuccessMessage(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.passwordResetLinkSentTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.checkEmailInstructions,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBackToLoginButton(AppLocalizations l10n) {
    return CustomButton(
      text: l10n.backToLogin,
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
        final localizations = AppLocalizations.of(context);
        _showErrorSnackBar(
          authProvider.errorMessage ?? localizations.failedToSendResetLink,
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
