import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_client.dart';
import '../../../web_ui/utils/platform_router.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('=== LOGIN SCREEN INITIALIZED ===');
    _testApiConnectivity();
  }

  Future<void> _testApiConnectivity() async {
    try {
      debugPrint('Testing API connectivity...');
      final isConnected = await ApiClient.testConnectivity();
      debugPrint('API Connectivity Test Result: $isConnected');
      if (!isConnected) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          setState(() {
            _errorMessage = localizations.cannotConnectToServer;
          });
        }
      }
    } catch (e) {
      debugPrint('API Connectivity Test Error: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.networkErrorLabel(e.toString());
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== LOGIN SCREEN BUILD METHOD CALLED ===');
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo and Title
                _buildHeader(l10n),

                const SizedBox(height: 40),

                // Login Form Card
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
                      // Login Form
                      _buildLoginForm(l10n),

                      const SizedBox(height: 24),

                      // Login Button
                      _buildLoginButton(l10n),

                      const SizedBox(height: 16),

                      // Forgot Password
                      _buildForgotPasswordLink(l10n),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Register Link
                _buildRegisterLink(l10n),
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
        // App Logo with gradient background
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
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 77),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            Icons.library_books,
            color: theme.colorScheme.onPrimary,
            size: 48,
          ),
        ),

        const SizedBox(height: 24),

        // App Name
        Text(
          l10n.appName,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 8),

        // Welcome Text
        Text(
          l10n.welcome,
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(AppLocalizations l10n) {
    return Column(
      children: [
        // Error message (if any)
        if (_errorMessage != null)
          ErrorMessage(
            message: _errorMessage!,
            onRetry: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),

        // Email Field
        CustomTextField(
          label: l10n.emailLabelLogin,
          hint: l10n.emailHint,
          controller: _emailController,
          type: TextFieldType.email,
          validator: Validators.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.email_outlined),
        ),

        const SizedBox(height: AppDimensions.spacingL),

        // Password Field
        CustomTextField(
          label: l10n.passwordLabelLogin,
          hint: l10n.passwordHint,
          controller: _passwordController,
          type: TextFieldType.password,
          validator: Validators.password,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_outlined),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
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
            text: l10n.loginButton,
            onPressed: authProvider.isLoading
                ? null
                : () {
                    debugPrint('=== LOGIN BUTTON CLICKED ===');
                    debugPrint(
                      'AuthProvider isLoading: ${authProvider.isLoading}',
                    );
                    _handleLogin();
                  },
            type: ButtonType.primary,
            size: ButtonSize.large,
            isFullWidth: true,
            isLoading: authProvider.isLoading,
            textColor: theme.colorScheme.onPrimary,
            backgroundColor: theme.colorScheme.primary,
          ),
        );
      },
    );
  }

  Widget _buildForgotPasswordLink(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
        );
      },
      child: Text(
        l10n.forgotPasswordQuestion,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRegisterLink(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.dontHaveAccount,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            );
          },
          child: Text(
            l10n.registerLink,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    debugPrint('=== LOGIN ATTEMPT STARTED ===');
    debugPrint('Email: ${_emailController.text.trim()}');
    debugPrint('Password length: ${_passwordController.text.length}');
    debugPrint('API Base URL: ${ApiClient.baseUrl}');

    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    debugPrint('Form validation passed, calling auth provider...');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    debugPrint('Login result: $success');
    debugPrint('Error message: ${authProvider.errorMessage}');

    if (mounted) {
      if (success) {
        debugPrint('Login successful, updating providers and navigating...');
        debugPrint('User role from auth provider: ${authProvider.userRole}');
        debugPrint('User object: ${authProvider.user}');

        // Update all providers with the new token
        AuthService.updateProvidersWithToken(context, authProvider.token);

        // Navigate to appropriate screen based on user role
        _navigateToHome(authProvider.userRole);
      } else {
        debugPrint('Login failed, showing error: ${authProvider.errorMessage}');
        final localizations = AppLocalizations.of(context);
        // Localize the error message if it's "Invalid credentials provided"
        String errorMessage =
            authProvider.errorMessage ?? localizations.loginFailed;
        if (errorMessage.toLowerCase().contains('invalid credentials')) {
          errorMessage = localizations.invalidCredentialsProvided;
        }
        _showErrorSnackBar(errorMessage);
      }
    }
    debugPrint('=== LOGIN ATTEMPT COMPLETED ===');
  }

  void _navigateToHome(String? userRole) {
    debugPrint('Navigating to home for user role: $userRole');

    // Use PlatformRouter to get the appropriate route based on platform and role
    final route = PlatformRouter.getRouteForUser(userRole);
    debugPrint('PlatformRouter determined route: $route');
    Navigator.pushReplacementNamed(context, route);
  }

  void _showErrorSnackBar(String message) {
    setState(() {
      _errorMessage = message;
    });
  }
}
