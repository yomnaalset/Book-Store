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
          // Labels will be localized in the dropdown widget
          _userTypeOptions = [
            {'value': 'customer', 'label': 'customer'},
            {'value': 'delivery_admin', 'label': 'delivery_admin'},
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
        title: Text(
          l10n.registerTitle,
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Registration Form Card
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
                      // User Type Selection
                      _buildUserTypeSelection(),

                      const SizedBox(height: 24),

                      // Registration Form
                      _buildRegistrationForm(l10n),

                      const SizedBox(height: 24),

                      // Register Button
                      _buildRegisterButton(l10n),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

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
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.userType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _isLoadingUserTypes
            ? const LoadingIndicator()
            : Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedUserType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  items: _userTypeOptions.map((userType) {
                    final localizations = AppLocalizations.of(context);
                    final value = userType['value'] ?? '';
                    String label;
                    switch (value) {
                      case 'customer':
                        label = localizations.customer;
                        break;
                      case 'delivery_admin':
                        label = localizations.deliveryManager;
                        break;
                      default:
                        label = userType['label'] ?? value;
                    }
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserType = value!;
                    });
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildRegistrationForm(AppLocalizations l10n) {
    return Column(
      children: [
        // First Name Field
        CustomTextField(
          label: l10n.firstNameLabel,
          hint: l10n.enterFirstName,
          controller: _firstNameController,
          validator: Validators.name,
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: AppDimensions.spacingM),

        // Last Name Field
        CustomTextField(
          label: l10n.lastNameLabel,
          hint: l10n.enterLastName,
          controller: _lastNameController,
          validator: Validators.name,
          textInputAction: TextInputAction.next,
        ),

        const SizedBox(height: AppDimensions.spacingM),

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

        const SizedBox(height: AppDimensions.spacingM),

        // Phone Field
        CustomTextField(
          label: l10n.phoneOptional,
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
          label: l10n.passwordLabelLogin,
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
          label: l10n.confirmPasswordLabel,
          hint: l10n.confirmPasswordHint,
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
            text: l10n.registerButton,
            onPressed: authProvider.isLoading ? null : _handleRegister,
            type: ButtonType.primary,
            size: ButtonSize.large,
            isFullWidth: true,
            isLoading: authProvider.isLoading,
          ),
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
          l10n.alreadyHaveAccount,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            l10n.loginLink,
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
      final localizations = AppLocalizations.of(context);
      if (success) {
        _showSuccessSnackBar(localizations.registrationSuccessful);
        Navigator.pop(context);
      } else {
        _showErrorSnackBar(
          authProvider.errorMessage ?? localizations.registrationFailed,
        );
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
