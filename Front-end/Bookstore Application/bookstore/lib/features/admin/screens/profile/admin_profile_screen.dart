import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/common/custom_button.dart';
import '../../../../core/widgets/common/custom_text_field.dart';
import '../../../../core/widgets/common/loading_indicator.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../../routes/app_routes.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isLoadingUserData = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload if we haven't loaded data yet
    if (!_isLoadingUserData) {
      _loadUserData();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload user data when app is resumed (only if not already loading)
      if (!_isLoadingUserData) {
        _loadUserData();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Prevent multiple simultaneous calls
    if (_isLoadingUserData) {
      debugPrint('AdminProfileScreen: Already loading user data, skipping...');
      return;
    }

    _isLoadingUserData = true;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      // Ensure ProfileProvider has the latest token
      profileProvider.autoRefreshToken(context);

      // First, try to load fresh data from server using AuthService
      if (authProvider.token != null) {
        debugPrint('AdminProfileScreen: Loading fresh data from server...');
        await AuthService.getUserProfile(context);

        // Wait a bit for the AuthProvider to be updated
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Check if widget is still mounted before using context
      if (!mounted) return;

      // Then load user data from AuthProvider (which will have the latest data)
      final user = authProvider.user;
      debugPrint(
        'AdminProfileScreen: Loading user data - User: ${user?.firstName} ${user?.lastName}',
      );
      debugPrint('AdminProfileScreen: User phone: ${user?.phone}');
      debugPrint('AdminProfileScreen: User address: ${user?.address}');
      debugPrint('AdminProfileScreen: User city: ${user?.city}');
      debugPrint('AdminProfileScreen: User zipCode: ${user?.zipCode}');
      debugPrint('AdminProfileScreen: User country: ${user?.country}');
      debugPrint('AdminProfileScreen: User dateOfBirth: ${user?.dateOfBirth}');

      if (user != null) {
        _firstNameController.text = user.firstName;
        _lastNameController.text = user.lastName;
        _emailController.text = user.email;
        _phoneController.text = user.phone ?? '';
        _dateOfBirthController.text = user.dateOfBirth != null
            ? '${user.dateOfBirth!.day.toString().padLeft(2, '0')}/${user.dateOfBirth!.month.toString().padLeft(2, '0')}/${user.dateOfBirth!.year}'
            : '';
        _addressController.text = user.address ?? '';
        _cityController.text = user.city ?? '';
        _zipCodeController.text = user.zipCode ?? '';
        _countryController.text = user.country ?? '';

        debugPrint('AdminProfileScreen: User data loaded successfully');

        // Force UI update
        if (mounted) {
          setState(() {});
        }
      } else {
        debugPrint('AdminProfileScreen: No user data available');
      }
    } finally {
      _isLoadingUserData = false;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get the current token from AuthProvider
      final token = authProvider.token;
      final localizations = AppLocalizations.of(context);
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.authenticationTokenNotAvailable),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get current user data for comparison
      final currentUser = authProvider.user;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.userDataNotAvailable),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Only include changed fields in the update
      final Map<String, dynamic> changedFields = {};

      // Check each field for changes
      if (_firstNameController.text.trim() != currentUser.firstName) {
        changedFields['first_name'] = _firstNameController.text.trim();
      }

      if (_lastNameController.text.trim() != currentUser.lastName) {
        changedFields['last_name'] = _lastNameController.text.trim();
      }

      // Check if email has changed - this requires special handling
      final newEmail = _emailController.text.trim();
      if (newEmail.toLowerCase() != currentUser.email.toLowerCase()) {
        // Email change requires password verification, so we'll handle it separately
        await _handleEmailChange(
          newEmail: newEmail,
          currentEmail: currentUser.email,
        );
        setState(() => _isLoading = false);
        return; // Exit early since email change is handled separately
      } else if (newEmail != currentUser.email) {
        // Same email but different case - show warning
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.emailSameNoChanges),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (_phoneController.text.trim() != (currentUser.phone ?? '')) {
        changedFields['phone_number'] = _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim();
      }

      // Check date of birth changes
      final currentDateOfBirth = currentUser.dateOfBirth != null
          ? '${currentUser.dateOfBirth!.day.toString().padLeft(2, '0')}/${currentUser.dateOfBirth!.month.toString().padLeft(2, '0')}/${currentUser.dateOfBirth!.year}'
          : '';
      if (_dateOfBirthController.text.trim() != currentDateOfBirth) {
        if (_dateOfBirthController.text.trim().isEmpty) {
          changedFields['date_of_birth'] = null;
        } else {
          // Parse the date from DD/MM/YYYY format
          try {
            final parts = _dateOfBirthController.text.trim().split('/');
            if (parts.length == 3) {
              final day = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              final date = DateTime(year, month, day);
              changedFields['date_of_birth'] = date.toIso8601String().split(
                'T',
              )[0];
            }
          } catch (e) {
            debugPrint('Error parsing date of birth: $e');
          }
        }
      }

      if (_addressController.text.trim() != (currentUser.address ?? '')) {
        changedFields['address'] = _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim();
      }

      if (_cityController.text.trim() != (currentUser.city ?? '')) {
        changedFields['city'] = _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim();
      }

      if (_zipCodeController.text.trim() != (currentUser.zipCode ?? '')) {
        changedFields['zip_code'] = _zipCodeController.text.trim().isEmpty
            ? null
            : _zipCodeController.text.trim();
      }

      if (_countryController.text.trim() != (currentUser.country ?? '')) {
        changedFields['country'] = _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim();
      }

      // Check if there are any changes
      if (changedFields.isEmpty) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.noChangesDetected),
            backgroundColor: AppColors.warning,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Ensure ProfileProvider has the token
      profileProvider.setToken(token);

      final success = await profileProvider.updateProfile(
        changedFields,
        token: token, // Explicitly pass the token
        userType: currentUser.userType, // Pass user type for endpoint selection
        context: context, // Pass context for AuthProvider refresh
      );

      if (mounted) {
        if (success) {
          setState(() => _isEditing = false);

          // Update the local user data in AuthProvider with changed data only
          authProvider.updateUserProfile(changedFields);

          // Show specific success message based on what was updated
          String successMessage = _getSuccessMessage(changedFields);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: AppColors.success,
            ),
          );

          // Refresh auth provider user data from server to ensure consistency
          await AuthService.getUserProfile(context);

          // Force a rebuild to ensure UI updates
          if (mounted) {
            setState(() {});
          }
        } else {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                profileProvider.errorMessage ??
                    localizations.failedToUpdateProfile,
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorUpdatingProfile(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to generate appropriate success messages
  String _getSuccessMessage(Map<String, dynamic> changedFields) {
    final localizations = AppLocalizations.of(context);
    if (changedFields.isEmpty) {
      return localizations.noChangesDetected;
    }

    if (changedFields.length == 1) {
      final field = changedFields.keys.first;
      switch (field) {
        case 'phone_number':
          return localizations.phoneNumberUpdatedSuccessfully;
        case 'first_name':
          return localizations.firstNameUpdatedSuccessfully;
        case 'last_name':
          return localizations.lastNameUpdatedSuccessfully;
        case 'address':
          return localizations.addressUpdatedSuccessfully;
        case 'city':
          return localizations.cityUpdatedSuccessfully;
        case 'zip_code':
          return localizations.zipCodeUpdatedSuccessfully;
        case 'country':
          return localizations.countryUpdatedSuccessfully;
        default:
          return localizations.profileUpdatedSuccessfully;
      }
    } else {
      return localizations.profileUpdatedSuccessfullyFields(
        changedFields.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.personalProfile),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Consumer2<AuthProvider, ProfileProvider>(
        builder: (context, authProvider, profileProvider, child) {
          if (profileProvider.isLoading && !_isEditing) {
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
                  // Profile Picture Section
                  _buildProfilePictureSection(authProvider),

                  const SizedBox(height: AppDimensions.spacingL),

                  // Personal Information
                  _buildPersonalInfoSection(),

                  const SizedBox(height: AppDimensions.spacingL),

                  // Contact Information
                  _buildContactInfoSection(),

                  const SizedBox(height: AppDimensions.spacingL),

                  // Address Information
                  _buildAddressSection(),

                  // Action Buttons
                  if (_isEditing) _buildActionButtons(),

                  const SizedBox(height: AppDimensions.spacingL),

                  // Other Options
                  _buildOtherOptions(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfilePictureSection(AuthProvider authProvider) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: _selectedImage != null
                ? FileImage(_selectedImage!)
                : (authProvider.user?.profilePicture != null
                      ? NetworkImage(authProvider.user!.profilePicture!)
                      : null),
            child:
                _selectedImage == null &&
                    authProvider.user?.profilePicture == null
                ? const Icon(
                    Icons.admin_panel_settings,
                    size: 60,
                    color: AppColors.primary,
                  )
                : null,
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: _isUploadingImage
                      ? null
                      : _handleProfilePictureUpdate,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    final localizations = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  localizations.personalInformation,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _firstNameController,
                    label: localizations.firstNameLabel,
                    enabled: _isEditing,
                    validator: Validators.name,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: CustomTextField(
                    controller: _lastNameController,
                    label: localizations.lastNameLabel,
                    enabled: _isEditing,
                    validator: Validators.name,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            CustomTextField(
              controller: _emailController,
              label: localizations.emailLabel,
              hint: _isEditing
                  ? localizations.pleaseEnterNewEmailAddress
                  : null,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    final localizations = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_phone, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  localizations.contactInformation,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            CustomTextField(
              controller: _phoneController,
              label: localizations.phoneNumber,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              validator: (value) {
                // Phone is optional but if provided, should be valid format
                if (value != null && value.trim().isNotEmpty) {
                  // ignore: deprecated_member_use
                  final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                  if (!phoneRegex.hasMatch(value.trim())) {
                    return localizations.pleaseEnterValidPhone;
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
            CustomTextField(
              controller: _dateOfBirthController,
              label: localizations.dateOfBirthLabel,
              enabled: _isEditing,
              keyboardType: TextInputType.datetime,
              hint: localizations.dateFormatHint,
              onTap: _isEditing ? _selectDateOfBirth : null,
              readOnly: true,
              validator: (value) {
                // Date of birth is optional but if provided, should be valid format
                if (value != null && value.trim().isNotEmpty) {
                  // ignore: deprecated_member_use
                  final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
                  if (!dateRegex.hasMatch(value.trim())) {
                    return localizations.pleaseEnterDateFormat;
                  }
                  // Additional validation for valid date
                  try {
                    // ignore: deprecated_member_use
                    final parts = value.trim().split('/');
                    // ignore: deprecated_member_use
                    if (parts.length == 3) {
                      final day = int.parse(parts[0]);
                      final month = int.parse(parts[1]);
                      final year = int.parse(parts[2]);
                      final date = DateTime(year, month, day);
                      // Check if the date is valid and not in the future
                      if (date.year != year ||
                          date.month != month ||
                          date.day != day) {
                        return localizations.invalidDateFormat;
                      }
                      if (date.isAfter(DateTime.now())) {
                        return localizations.invalidDateFormat;
                      }
                    }
                  } catch (e) {
                    return localizations.invalidDateFormat;
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    final localizations = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: AppDimensions.spacingM),
                Text(
                  localizations.addressInformation,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            CustomTextField(
              controller: _addressController,
              label: localizations.streetAddress,
              enabled: _isEditing,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _cityController,
                    label: localizations.cityLabel,
                    enabled: _isEditing,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: CustomTextField(
                    controller: _stateController,
                    label: localizations.stateProvince,
                    enabled: _isEditing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _zipCodeController,
                    label: localizations.zipPostalCode,
                    enabled: _isEditing,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: CustomTextField(
                    controller: _countryController,
                    label: localizations.countryLabel,
                    enabled: _isEditing,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final localizations = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: localizations.cancel,
            onPressed: () {
              setState(() {
                _isEditing = false;
                _loadUserData(); // Reset to original values
              });
            },
            type: ButtonType.outline,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: CustomButton(
            text: _isLoading ? localizations.saving : localizations.saveChanges,
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ),
      ],
    );
  }

  Widget _buildOtherOptions() {
    final localizations = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.accountOptions,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            ListTile(
              leading: const Icon(Icons.lock, color: AppColors.primary),
              title: Text(localizations.changePassword),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.changePassword);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.notifications,
                color: AppColors.primary,
              ),
              title: Text(localizations.notificationSettings),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.notificationSettings);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text(
                localizations.signOut,
                style: const TextStyle(color: AppColors.error),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
              onPressed: () => Navigator.of(dialogContext).pop(),
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
                Navigator.of(dialogContext).pop();
                await _logout();
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

  Future<void> _logout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (mounted) {
        AuthService.clearProvidersTokens(context);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.signOutFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirthController.text.isNotEmpty
          ? _parseDateOfBirth(_dateOfBirthController.text)
          : DateTime.now().subtract(
              const Duration(days: 365 * 18),
            ), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _dateOfBirthController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  DateTime _parseDateOfBirth(String dateString) {
    try {
      final parts = dateString.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    return DateTime.now().subtract(const Duration(days: 365 * 18));
  }

  Future<void> _handleEmailChange({
    required String newEmail,
    required String currentEmail,
  }) async {
    debugPrint('AdminProfileScreen: Starting email change process');
    debugPrint('AdminProfileScreen: newEmail: $newEmail');
    debugPrint('AdminProfileScreen: currentEmail: $currentEmail');

    // Capture providers before async operation
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    // Show password verification dialog
    final password = await _showPasswordDialog();
    if (password == null) {
      debugPrint('AdminProfileScreen: User cancelled password dialog');
      return; // User cancelled
    }

    try {
      debugPrint('AdminProfileScreen: Token available: ${token != null}');
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Authentication token not available. Please log in again.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      debugPrint('AdminProfileScreen: Calling ProfileProvider.changeEmail');
      // Use the email change service
      final success = await profileProvider.changeEmail(
        token: token,
        newEmail: newEmail,
        confirmEmail: newEmail,
        currentPassword: password,
      );

      if (!mounted) return;

      final localizations = AppLocalizations.of(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.emailChangedSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );

        // Logout user since email changed
        await authProvider.logout();

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              profileProvider.errorMessage ?? localizations.failedToChangeEmail,
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorUpdatingProfile(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    final localizations = AppLocalizations.of(context);

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.verifyPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localizations.verifyPasswordMessage,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: localizations.currentPassword,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(passwordController.text.trim());
              }
            },
            child: Text(localizations.verify),
          ),
        ],
      ),
    );
  }

  Future<void> _handleProfilePictureUpdate() async {
    try {
      // Show options for camera or gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      );

      if (source != null) {
        final XFile? image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });

          // Upload the image
          await _uploadProfilePicture();
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorPickingImage(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final token = authProvider.token;
      final localizations = AppLocalizations.of(context);
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.authenticationTokenNotAvailable),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      profileProvider.setToken(token);

      final success = await profileProvider.uploadProfilePicture(
        _selectedImage!.path,
        token: token,
      );

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.profilePictureUpdatedSuccessfully),
              backgroundColor: AppColors.success,
            ),
          );

          // Refresh user data to get the new profile picture URL
          await AuthService.getUserProfile(context);

          // Clear the selected image since it's now uploaded
          setState(() {
            _selectedImage = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                profileProvider.errorMessage ??
                    localizations.failedToUploadProfilePicture,
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.errorUploadingProfilePicture(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }
}
