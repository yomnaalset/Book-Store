import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/utils/validators.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _dateOfBirthController = TextEditingController();

  // Email change controllers
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  bool _isEditing = false;
  bool _isChangingEmail = false;
  bool _obscureCurrentPassword = true;
  bool _isUploadingImage = false;
  bool _isLoadingData = false;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUserData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('ProfileScreen: didChangeDependencies called');
    // Don't reload data here to prevent infinite loops
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('ProfileScreen: didUpdateWidget called');
    // Don't reload data here to prevent infinite loops
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _dateOfBirthController.dispose();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Prevent multiple simultaneous loading operations
    if (_isLoadingData) {
      debugPrint('ProfileScreen: Already loading data, skipping...');
      return;
    }

    _isLoadingData = true;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      // Always load fresh data from server when profile screen opens
      if (authProvider.token != null) {
        debugPrint('ProfileScreen: Loading fresh profile data from server');
        await profileProvider.loadProfile(
          token: authProvider.token,
          context: context,
        );
      } else {
        debugPrint('ProfileScreen: No authentication token available');
      }

      // Load user data from AuthProvider
      final currentUser = authProvider.user;
      debugPrint(
        'ProfileScreen: Loading user data - User: ${currentUser?.firstName} ${currentUser?.lastName}',
      );

      if (currentUser != null) {
        // Only update controllers if the data has actually changed
        if (_firstNameController.text != currentUser.firstName) {
          _firstNameController.text = currentUser.firstName;
        }
        if (_lastNameController.text != currentUser.lastName) {
          _lastNameController.text = currentUser.lastName;
        }
        if (_emailController.text != currentUser.email) {
          _emailController.text = currentUser.email;
        }
        if (_phoneController.text != (currentUser.phone ?? '')) {
          _phoneController.text = currentUser.phone ?? '';
        }
        if (_addressController.text != (currentUser.address ?? '')) {
          _addressController.text = currentUser.address ?? '';
        }
        if (_cityController.text != (currentUser.city ?? '')) {
          _cityController.text = currentUser.city ?? '';
        }
        if (_zipCodeController.text != (currentUser.zipCode ?? '')) {
          _zipCodeController.text = currentUser.zipCode ?? '';
        }
        if (_countryController.text != (currentUser.country ?? '')) {
          _countryController.text = currentUser.country ?? '';
        }

        final dateOfBirthText = currentUser.dateOfBirth != null
            ? '${currentUser.dateOfBirth!.year}-${currentUser.dateOfBirth!.month.toString().padLeft(2, '0')}-${currentUser.dateOfBirth!.day.toString().padLeft(2, '0')}'
            : '';
        if (_dateOfBirthController.text != dateOfBirthText) {
          _dateOfBirthController.text = dateOfBirthText;
        }
      } else {
        debugPrint('ProfileScreen: No user data available');
      }
    } finally {
      _isLoadingData = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint(
          'ProfileScreen: Consumer builder called - AuthProvider user: ${authProvider.user?.firstName} ${authProvider.user?.lastName}',
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
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
              if (profileProvider.isLoading) {
                return const Center(child: LoadingIndicator());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Picture Section
                      _buildProfilePictureSection(),

                      const SizedBox(height: AppDimensions.spacingL),

                      // Personal Information
                      _buildPersonalInfoSection(),

                      const SizedBox(height: AppDimensions.spacingL),

                      // Contact Information
                      _buildContactInfoSection(),

                      const SizedBox(height: AppDimensions.spacingL),

                      // Address Information
                      _buildAddressSection(),

                      const SizedBox(height: AppDimensions.spacingL),

                      // Action Buttons
                      if (_isEditing) _buildActionButtons(profileProvider),

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
      },
    );
  }

  void _resetFormData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
      _cityController.text = user.city ?? '';
      _zipCodeController.text = user.zipCode ?? '';
      _countryController.text = user.country ?? '';
      _dateOfBirthController.text = user.dateOfBirth != null
          ? '${user.dateOfBirth!.year}-${user.dateOfBirth!.month.toString().padLeft(2, '0')}-${user.dateOfBirth!.day.toString().padLeft(2, '0')}'
          : '';
    }
  }

  Widget _buildProfilePictureSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 26),
            backgroundImage: _selectedImage != null
                ? FileImage(_selectedImage!)
                : (Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).user?.profilePicture !=
                          null
                      ? NetworkImage(
                          Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).user!.profilePicture!,
                        )
                      : null),
            child:
                _selectedImage == null &&
                    (Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).user?.profilePicture ==
                        null)
                ? Icon(
                    Icons.person,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isUploadingImage
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.camera_alt,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'First Name',
                    controller: _firstNameController,
                    enabled: _isEditing,
                    validator: Validators.name,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: CustomTextField(
                    label: 'Last Name',
                    controller: _lastNameController,
                    enabled: _isEditing,
                    validator: Validators.name,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.spacingM),

            // Date of Birth Field
            CustomTextField(
              label: 'Date of Birth',
              controller: _dateOfBirthController,
              enabled: _isEditing,
              keyboardType: TextInputType.datetime,
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              hint: 'YYYY-MM-DD',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return null; // Date of birth is optional
                }
                // Basic date format validation
                // ignore: deprecated_member_use
                final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                if (!dateRegex.hasMatch(value)) {
                  return 'Please enter date in YYYY-MM-DD format';
                }
                return null;
              },
            ),

            // Calendar button for date selection
            if (_isEditing) ...[
              const SizedBox(height: AppDimensions.spacingS),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _selectDateOfBirth,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Select Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeL,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_isEditing && !_isChangingEmail)
                  TextButton.icon(
                    onPressed: _handleStartEmailChange,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Change Email'),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Current email display
            if (!_isChangingEmail)
              CustomTextField(
                label: 'Email',
                controller: _emailController,
                enabled: false,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
                suffixIcon: _isEditing
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _handleStartEmailChange,
                      )
                    : null,
              ),

            // Email change form
            if (_isChangingEmail) ...[
              CustomTextField(
                label: 'New Email',
                controller: _newEmailController,
                enabled: true,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              CustomTextField(
                label: 'Confirm New Email',
                controller: _confirmEmailController,
                enabled: true,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new email';
                  }
                  if (value != _newEmailController.text) {
                    return 'Email addresses do not match';
                  }
                  return null;
                },
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              CustomTextField(
                label: 'Current Password',
                controller: _currentPasswordController,
                enabled: true,
                obscureText: _obscureCurrentPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Current password is required';
                  }
                  return null;
                },
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrentPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancel',
                      onPressed: _handleCancelEmailChange,
                      type: ButtonType.secondary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingM),
                  Expanded(
                    child: CustomButton(
                      text: 'Change Email',
                      onPressed: _handleChangeEmail,
                      type: ButtonType.primary,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppDimensions.spacingM),

            CustomTextField(
              label: 'Phone Number',
              controller: _phoneController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              validator: (value) {
                // Phone is optional but if provided, should be valid format
                if (value != null && value.trim().isNotEmpty) {
                  // ignore: deprecated_member_use
                  final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                  if (!phoneRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid phone number (e.g., +1234567890)';
                  }
                }
                return null;
              },
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Address Information',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),

            CustomTextField(
              label: 'Address',
              controller: _addressController,
              enabled: _isEditing,
              maxLines: 2,
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),

            const SizedBox(height: AppDimensions.spacingM),

            CustomTextField(
              label: 'City',
              controller: _cityController,
              enabled: _isEditing,
            ),

            const SizedBox(height: AppDimensions.spacingM),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'ZIP Code',
                    controller: _zipCodeController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: CustomTextField(
                    label: 'Country',
                    controller: _countryController,
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

  Widget _buildActionButtons(ProfileProvider profileProvider) {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Cancel',
            onPressed: () {
              setState(() => _isEditing = false);
              // Reset form data without triggering loading
              _resetFormData();
            },
            type: ButtonType.secondary,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: CustomButton(
            text: 'Save Changes',
            onPressed: profileProvider.isLoading ? null : _handleSaveProfile,
            type: ButtonType.primary,
            isLoading: profileProvider.isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildOtherOptions() {
    return const Column(
      children: [
        // No options - all moved to bottom navigation
      ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
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
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication token not available. Please log in again.',
            ),
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
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );

          // Refresh user data to get the new profile picture URL
          await authProvider.refreshUserData();

          // Clear the selected image since it's now uploaded
          setState(() {
            _selectedImage = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                profileProvider.errorMessage ??
                    'Failed to upload profile picture',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading profile picture: ${e.toString()}'),
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

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 20),
      ), // Default to 20 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      _dateOfBirthController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Get the current token from AuthProvider
    final token = authProvider.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Authentication token not available. Please log in again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Ensure ProfileProvider has the token
    profileProvider.setToken(token);

    // Get current user data for comparison
    final currentUser = authProvider.user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User data not available. Please log in again.'),
          backgroundColor: AppColors.error,
        ),
      );
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

    if (_phoneController.text.trim() != (currentUser.phone ?? '')) {
      changedFields['phone_number'] = _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim();
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

    // Handle date of birth
    final currentDateOfBirth = currentUser.dateOfBirth != null
        ? '${currentUser.dateOfBirth!.year}-${currentUser.dateOfBirth!.month.toString().padLeft(2, '0')}-${currentUser.dateOfBirth!.day.toString().padLeft(2, '0')}'
        : '';
    if (_dateOfBirthController.text.trim() != currentDateOfBirth) {
      changedFields['date_of_birth'] =
          _dateOfBirthController.text.trim().isEmpty
          ? null
          : _dateOfBirthController.text.trim();
    }

    // Check if there are any changes
    if (changedFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes detected.'),
          backgroundColor: AppColors.warning,
        ),
      );
      setState(() => _isEditing = false);
      return;
    }

    debugPrint(
      'ProfileScreen: Updating profile with token: ${token.substring(0, 20)}...',
    );
    debugPrint('ProfileScreen: Changed fields only: $changedFields');
    debugPrint('ProfileScreen: Total changed fields: ${changedFields.length}');

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
        debugPrint(
          'ProfileScreen: Updating local AuthProvider with changed data: $changedFields',
        );
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
        debugPrint('ProfileScreen: Refreshing user data from server...');
        await authProvider.refreshUserData();
        debugPrint(
          'ProfileScreen: User data refreshed. Current user: ${authProvider.user?.firstName} ${authProvider.user?.lastName}',
        );
        debugPrint(
          'ProfileScreen: User phone after refresh: ${authProvider.user?.phone}',
        );
        debugPrint(
          'ProfileScreen: User address after refresh: ${authProvider.user?.address}',
        );
        debugPrint(
          'ProfileScreen: User city after refresh: ${authProvider.user?.city}',
        );

        // Force a rebuild to ensure UI updates
        if (mounted) {
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              profileProvider.errorMessage ?? 'Failed to update profile',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleStartEmailChange() {
    setState(() {
      _isChangingEmail = true;
    });
  }

  void _handleCancelEmailChange() {
    setState(() {
      _isChangingEmail = false;
      _newEmailController.clear();
      _confirmEmailController.clear();
      _currentPasswordController.clear();
    });
  }

  Future<void> _handleChangeEmail() async {
    // Only validate the email change form fields, not the entire form
    if (_newEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a new email address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_confirmEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm your new email address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_newEmailController.text.trim() !=
        _confirmEmailController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email addresses do not match'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your current password'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Get the current token from AuthProvider
    final token = authProvider.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Authentication token not available. Please log in again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Ensure ProfileProvider has the token
    profileProvider.setToken(token);

    final success = await profileProvider.changeEmail(
      newEmail: _newEmailController.text.trim(),
      confirmEmail: _confirmEmailController.text.trim(),
      currentPassword: _currentPasswordController.text,
      token: token, // Explicitly pass the token
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email changed successfully! Please log in again with your new email.',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Logout user since email changed
        await authProvider.logout();

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              profileProvider.errorMessage ?? 'Failed to change email',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Helper method to generate appropriate success messages
  String _getSuccessMessage(Map<String, dynamic> changedFields) {
    if (changedFields.isEmpty) {
      return 'No changes detected.';
    }

    if (changedFields.length == 1) {
      final field = changedFields.keys.first;
      switch (field) {
        case 'date_of_birth':
          return 'Date of birth updated successfully.';
        case 'phone_number':
          return 'Phone number updated successfully.';
        case 'email':
          return 'Email address updated successfully.';
        case 'first_name':
          return 'First name updated successfully.';
        case 'last_name':
          return 'Last name updated successfully.';
        case 'address':
          return 'Address updated successfully.';
        case 'city':
          return 'City updated successfully.';
        case 'zip_code':
          return 'ZIP code updated successfully.';
        case 'country':
          return 'Country updated successfully.';
        default:
          return 'Profile updated successfully.';
      }
    } else {
      return 'Profile updated successfully! Updated ${changedFields.length} field(s).';
    }
  }
}
