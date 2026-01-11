import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

// Import File only on native platforms - use conditional import
import 'dart:io' if (dart.library.html) 'dart:html' as io;

// Type alias for File - only valid on native platforms
// On web, this will be dart:html.File but we never use it on web
typedef PlatformFile = io.File;

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  // Email change controllers
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isChangingEmail = false;
  bool _obscureCurrentPassword = true;
  bool _isUploadingImage = false;
  List<int>? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _selectedImagePath; // Store path separately for native upload
  final ImagePicker _imagePicker = ImagePicker();

  // Helper to get ImageProvider for selected image
  ImageProvider? _getSelectedImageProvider() {
    if (_selectedImageBytes != null) {
      return MemoryImage(Uint8List.fromList(_selectedImageBytes!));
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    // Don't reload data if we're in the middle of changing email
    if (_isChangingEmail) {
      debugPrint('Skipping _loadUserData because _isChangingEmail is true');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );

    // First, try to load fresh data from server
    if (authProvider.token != null) {
      await profileProvider.loadProfile(
        token: authProvider.token,
        context: context,
      );
    }

    // Then load user data from AuthProvider
    final user = authProvider.user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
      _cityController.text = user.city ?? '';
      _countryController.text = user.country ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

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
      return;
    }

    // Ensure ProfileProvider has the token
    profileProvider.setToken(token);

    // Get current user data for comparison
    final currentUser = authProvider.user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.userDataNotAvailable),
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

    if (_countryController.text.trim() != (currentUser.country ?? '')) {
      changedFields['country'] = _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim();
    }

    // Check if there are any changes
    if (changedFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.noChangesDetected),
          backgroundColor: AppColors.warning,
        ),
      );
      setState(() => _isEditing = false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await profileProvider.updateProfile(
        changedFields,
        token: token,
        userType: currentUser.userType,
        context: context,
      );

      if (mounted) {
        if (success) {
          setState(() => _isEditing = false);

          // Update the local user data in AuthProvider with changed data only
          authProvider.updateUserProfile(changedFields);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.profileUpdatedSuccessfullyFields(
                  changedFields.length,
                ),
              ),
              backgroundColor: AppColors.success,
            ),
          );

          // Refresh auth provider user data from server to ensure consistency
          await authProvider.refreshUserData();
        } else {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.failedToUpdateProfile}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).personalProfile,
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
        actions: [
          if (_isEditing)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
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
                    : Text(
                        AppLocalizations.of(context).save,
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
            ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  _buildProfileHeader(authProvider),
                  const SizedBox(height: 24),

                  // Personal Information
                  _buildPersonalInfoSection(theme),
                  const SizedBox(height: 24),

                  // Contact Information
                  _buildContactInfoSection(theme),
                  const SizedBox(height: 24),

                  // Address Information
                  _buildAddressSection(theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(AuthProvider authProvider) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      _getSelectedImageProvider() ??
                      (() {
                        final profilePictureUrl =
                            authProvider.user?.profilePicture;
                        if (profilePictureUrl != null &&
                            profilePictureUrl.isNotEmpty) {
                          // Convert relative path to absolute URL
                          final fullUrl =
                              ApiConfig.buildImageUrl(profilePictureUrl) ??
                              profilePictureUrl;

                          // Add cache-busting parameter only if not already present
                          try {
                            final uri = Uri.parse(fullUrl);
                            if (!uri.queryParameters.containsKey('t')) {
                              // Use a hash of the URL as cache buster to keep it stable per URL
                              final cacheBuster = fullUrl.hashCode
                                  .abs()
                                  .toString();
                              final urlWithCacheBuster = uri
                                  .replace(
                                    queryParameters: {
                                      ...uri.queryParameters,
                                      't': cacheBuster,
                                    },
                                  )
                                  .toString();
                              return NetworkImage(urlWithCacheBuster);
                            } else {
                              return NetworkImage(fullUrl);
                            }
                          } catch (e) {
                            // If URI parsing fails, use the URL as-is
                            debugPrint('Error parsing profile picture URL: $e');
                            return NetworkImage(fullUrl);
                          }
                        }
                        return null;
                      })(),
                  child:
                      _getSelectedImageProvider() == null &&
                          (authProvider.user?.profilePicture == null)
                      ? const Icon(
                          Icons.person,
                          size: 40,
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
                                    AppColors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: AppColors.white,
                              ),
                        onPressed: _isUploadingImage
                            ? null
                            : _handleProfilePictureUpdate,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        authProvider.user?.fullName ??
                            localizations.deliveryManager,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Builder(
                      builder: (context) {
                        return Text(
                          AppLocalizations.of(context).deliveryManager,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.personalInformation,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: localizations.firstNameLabel,
                            controller: _firstNameController,
                            enabled: _isEditing,
                            validator: Validators.name,
                            prefixIcon: const Icon(Icons.person_outlined),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            label: localizations.lastNameLabel,
                            controller: _lastNameController,
                            enabled: _isEditing,
                            validator: Validators.name,
                            prefixIcon: const Icon(Icons.person_outlined),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.contact_mail_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.contactInformation,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
                if (_isEditing && !_isChangingEmail)
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return TextButton.icon(
                        onPressed: _handleStartEmailChange,
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(localizations.changeEmail),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Current email display
            if (!_isChangingEmail)
              Builder(
                builder: (context) {
                  return CustomTextField(
                    label: AppLocalizations.of(context).email,
                    controller: _emailController,
                    enabled: false,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    suffixIcon: _isEditing
                        ? IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              debugPrint('Email edit button pressed');
                              _handleStartEmailChange();
                            },
                          )
                        : null,
                  );
                },
              ),

            // Email change form
            if (_isChangingEmail)
              Container(
                key: const ValueKey('email_change_form'),
                child: Column(
                  children: [
                    // Ensure the new email field is completely independent
                    Builder(
                      builder: (context) {
                        // Force clear the field when the form is built
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_newEmailController.text.isNotEmpty) {
                            debugPrint(
                              'Clearing new email field during build: ${_newEmailController.text}',
                            );
                            _newEmailController.clear();
                          }
                        });

                        final localizations = AppLocalizations.of(context);
                        return CustomTextField(
                          label: localizations.newEmailLabel,
                          controller: _newEmailController,
                          enabled: true,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          prefixIcon: const Icon(Icons.email_outlined),
                          hint: localizations.enterYourNewEmailAddress,
                          onChanged: (value) {
                            debugPrint('New email field changed to: $value');
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Ensure the confirm email field is completely independent
                    Builder(
                      builder: (context) {
                        // Force clear the field when the form is built
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_confirmEmailController.text.isNotEmpty) {
                            debugPrint(
                              'Clearing confirm email field during build: ${_confirmEmailController.text}',
                            );
                            _confirmEmailController.clear();
                          }
                        });

                        final localizations = AppLocalizations.of(context);
                        return CustomTextField(
                          label: localizations.confirmNewEmailLabel,
                          controller: _confirmEmailController,
                          enabled: true,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return localizations.pleaseConfirmYourNewEmail;
                            }
                            if (value != _newEmailController.text) {
                              return localizations.emailAddressesDoNotMatch;
                            }
                            return null;
                          },
                          prefixIcon: const Icon(Icons.email_outlined),
                          hint: localizations.confirmYourNewEmailAddress,
                          onChanged: (value) {
                            debugPrint(
                              'Confirm email field changed to: $value',
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return CustomTextField(
                          label: localizations.currentPasswordLabel,
                          controller: _currentPasswordController,
                          enabled: true,
                          obscureText: _obscureCurrentPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return localizations.currentPasswordRequired;
                            }
                            return null;
                          },
                          prefixIcon: const Icon(Icons.lock_outline),
                          hint: localizations.enterYourCurrentPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureCurrentPassword =
                                    !_obscureCurrentPassword;
                              });
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: localizations.cancel,
                                onPressed: _handleCancelEmailChange,
                                type: ButtonType.secondary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomButton(
                                text: localizations.changeEmail,
                                onPressed: _handleChangeEmail,
                                type: ButtonType.primary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return CustomTextField(
                  label: localizations.phoneNumber,
                  controller: _phoneController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    // Phone is optional but if provided, should be valid format
                    if (value != null && value.trim().isNotEmpty) {
                      // ignore: deprecated_member_use
                      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return localizations.pleaseEnterAValidPhoneNumber;
                      }
                    }
                    return null;
                  },
                  prefixIcon: const Icon(Icons.phone_outlined),
                );
              },
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                return CustomTextField(
                  label: AppLocalizations.of(context).addressLabel,
                  controller: _addressController,
                  enabled: _isEditing,
                  maxLines: 2,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.addressInformation,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: localizations.cityLabel,
                      controller: _cityController,
                      enabled: _isEditing,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: localizations.countryLabel,
                      controller: _countryController,
                      enabled: _isEditing,
                      prefixIcon: const Icon(Icons.public_outlined),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
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
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: Text(localizations.camera),
                          onTap: () =>
                              Navigator.of(context).pop(ImageSource.camera),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: Text(localizations.gallery),
                          onTap: () =>
                              Navigator.of(context).pop(ImageSource.gallery),
                        ),
                        ListTile(
                          leading: const Icon(Icons.cancel),
                          title: Text(localizations.cancel),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    );
                  },
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
          if (kIsWeb) {
            // For web, read bytes from XFile
            final bytes = await image.readAsBytes();
            setState(() {
              _selectedImageBytes = bytes;
              _selectedImageFileName = image.name;
            });
          } else {
            // For mobile/desktop, read file as bytes too (for consistency)
            final bytes = await image.readAsBytes();
            setState(() {
              _selectedImageBytes = bytes;
              _selectedImageFileName = image.name;
              // Store path for native upload
              _selectedImagePath = image.path;
              // File object not needed - we use bytes for display and path for upload
            });
          }

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
    if (kIsWeb && _selectedImageBytes == null) return;
    if (!kIsWeb && _selectedImagePath == null) return;

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

      // Use bytes method for web, path method for native
      final success = kIsWeb && _selectedImageBytes != null
          ? await profileProvider.uploadProfilePictureBytes(
              _selectedImageBytes!,
              fileName: _selectedImageFileName ?? 'profile_picture.jpg',
              token: token,
            )
          : !kIsWeb && _selectedImagePath != null
          ? await profileProvider.uploadProfilePicture(
              _selectedImagePath!,
              token: token,
            )
          : false;

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.profilePictureUpdatedSuccessfully),
              backgroundColor: AppColors.success,
            ),
          );

          // Refresh user data to get the new profile picture URL
          await authProvider.refreshUserData();

          // Wait a bit to ensure the UI rebuilds with the new image
          await Future.delayed(const Duration(milliseconds: 100));

          // Clear the selected image since it's now uploaded
          // Keep it a bit longer to ensure smooth transition
          setState(() {
            _selectedImageBytes = null;
            _selectedImagePath = null;
            _selectedImageFileName = null;
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

  void _handleStartEmailChange() {
    debugPrint('Starting email change - clearing all fields');

    // Clear the email change fields when starting
    _newEmailController.clear();
    _confirmEmailController.clear();
    _currentPasswordController.clear();

    // Force a rebuild to ensure fields are cleared
    setState(() {
      _isChangingEmail = true;
    });

    // Additional clear after setState to ensure fields are empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('PostFrameCallback - clearing fields again');
      _newEmailController.clear();
      _confirmEmailController.clear();
      _currentPasswordController.clear();

      // Force another rebuild to ensure UI reflects the cleared state
      if (mounted) {
        setState(() {});
      }
    });

    debugPrint('Email change form initialized with empty fields');
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
    // Clear any previous error messages
    debugPrint('Starting email change process...');
    debugPrint('New email: ${_newEmailController.text}');
    debugPrint('Confirm email: ${_confirmEmailController.text}');
    debugPrint(
      'Current password length: ${_currentPasswordController.text.length}',
    );

    final localizations = AppLocalizations.of(context);
    // Only validate the email change form fields, not the entire form
    if (_newEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseEnterNewEmail),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_confirmEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseConfirmNewEmailAddress),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_newEmailController.text.trim() !=
        _confirmEmailController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.emailAddressesDoNotMatch),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseEnterCurrentPassword),
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
        SnackBar(
          content: Text(localizations.authenticationTokenNotAvailable),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Ensure ProfileProvider has the token
    profileProvider.setToken(token);

    debugPrint('Calling profileProvider.changeEmail with:');
    debugPrint('  newEmail: ${_newEmailController.text.trim()}');
    debugPrint('  confirmEmail: ${_confirmEmailController.text.trim()}');
    debugPrint('  token: ${token.substring(0, 20)}...');

    final success = await profileProvider.changeEmail(
      newEmail: _newEmailController.text.trim(),
      confirmEmail: _confirmEmailController.text.trim(),
      currentPassword: _currentPasswordController.text,
      token: token,
    );

    debugPrint('Email change result: $success');

    if (mounted) {
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
            '/login',
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
    }
  }
}
