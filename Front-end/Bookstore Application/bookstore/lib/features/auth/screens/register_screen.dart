import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../services/auth_api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedUserType = 'customer';
  List<Map<String, String>> _userTypeOptions = [];
  bool _isLoadingUserTypes = true;

  @override
  void initState() {
    super.initState();
    debugPrint('=== REGISTER SCREEN INITIALIZED ===');
    _loadUserTypes();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserTypes() async {
    debugPrint('RegisterScreen: Loading user types from server...');
    try {
      final userTypes = await AuthApiService.getUserTypeOptions();
      debugPrint('RegisterScreen: User types loaded: $userTypes');

      if (mounted) {
        setState(() {
          _userTypeOptions = userTypes;
          _isLoadingUserTypes = false;
          if (userTypes.isNotEmpty) {
            _selectedUserType = userTypes.first['value'] ?? 'customer';
          }
        });
      }
    } catch (e) {
      debugPrint('RegisterScreen: Error loading user types: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserTypes = false;
          // Fallback to default options (never include library_admin in fallback)
          _userTypeOptions = [
            {'value': 'customer', 'label': 'Customer'},
            {'value': 'delivery_admin', 'label': 'Delivery Administrator'},
          ];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== REGISTER SCREEN BUILD METHOD CALLED ===');
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Register'),
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
                const SizedBox(height: AppDimensions.spacingL),

                // User Type Selection
                _buildUserTypeSelection(),

                const SizedBox(height: AppDimensions.spacingL),

                // Registration Form
                _buildRegistrationForm(l10n),

                const SizedBox(height: AppDimensions.spacingL),

                // Register Button
                _buildRegisterButton(l10n),

                const SizedBox(height: AppDimensions.spacingL),

                // Login Link
                _buildLoginLink(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeSelection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Type',
          style: TextStyle(
            fontSize: AppDimensions.fontSizeM,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingS),
        _isLoadingUserTypes
            ? const LoadingIndicator()
            : DropdownButtonFormField<String>(
                initialValue: _selectedUserType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingM,
                    vertical: AppDimensions.paddingM,
                  ),
                ),
                items: _userTypeOptions.map((userType) {
                  return DropdownMenuItem<String>(
                    value: userType['value'],
                    child: Text(userType['label'] ?? userType['value'] ?? ''),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUserType = value!;
                  });
                },
              ),
      ],
    );
  }

  Widget _buildRegistrationForm(AppLocalizations l10n) {
    return Column(
      children: [
        // First Name Field
        CustomTextField(
          label: 'First Name',
          hint: 'Enter your first name',
          controller: _firstNameController,
          validator: Validators.name,
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Last Name Field
        CustomTextField(
          label: 'Last Name',
          hint: 'Enter your last name',
          controller: _lastNameController,
          validator: Validators.name,
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Email Field
        CustomTextField(
          label: 'Email',
          hint: l10n.emailHint,
          controller: _emailController,
          type: TextFieldType.email,
          validator: Validators.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.email_outlined),
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Phone Field
        CustomTextField(
          label: 'Phone (Optional)',
          hint: l10n.phoneHint,
          controller: _phoneController,
          type: TextFieldType.phone,
          validator: Validators.optionalPhone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.phone_outlined),
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Password Field
        CustomTextField(
          label: 'Password',
          hint: l10n.passwordHint,
          controller: _passwordController,
          type: TextFieldType.password,
          validator: Validators.password,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.lock_outlined),
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Confirm Password Field
        CustomTextField(
          label: 'Confirm Password',
          hint: 'Confirm your password',
          controller: _confirmPasswordController,
          type: TextFieldType.password,
          validator: (value) =>
              Validators.confirmPassword(value, _passwordController.text),
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_outlined),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(AppLocalizations l10n) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return CustomButton(
          text: 'Register',
          onPressed: authProvider.isLoading ? null : _handleRegister,
          type: ButtonType.primary,
          size: ButtonSize.large,
          isFullWidth: true,
          isLoading: authProvider.isLoading,
        );
      },
    );
  }

  Widget _buildLoginLink(AppLocalizations l10n) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            'Login',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.register(
      email: _emailController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      phone: _phoneController.text.trim(),
      userType: _selectedUserType,
    );

    if (mounted) {
      if (success) {
        _showSuccessSnackBar(
          'Registration successful! Please check your email for verification.',
        );
        Navigator.pop(context);
      } else {
        _showErrorSnackBar(authProvider.errorMessage ?? 'Registration failed');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
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
