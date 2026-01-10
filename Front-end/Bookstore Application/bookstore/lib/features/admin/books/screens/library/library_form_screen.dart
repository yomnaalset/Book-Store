import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../providers/library_manager/library_provider.dart';
import '../../../../../../features/admin/models/library.dart';
import '../../../../../../core/localization/app_localizations.dart';
import '../../../../../../core/services/api_config.dart';

class LibraryFormScreen extends StatefulWidget {
  final Library? library;

  const LibraryFormScreen({super.key, this.library});

  @override
  State<LibraryFormScreen> createState() => _LibraryFormScreenState();
}

class _LibraryFormScreenState extends State<LibraryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();

  bool _isLoading = false;
  bool _isActive = true;
  File? _selectedImage; // For mobile/desktop
  Uint8List? _selectedImageBytes; // For web
  bool _logoRemoved = false; // Track if user explicitly removed the logo
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    debugPrint(
      'LibraryFormScreen: initState - library: ${widget.library?.name ?? "null"}',
    );
    if (widget.library != null) {
      _populateForm();
    } else {
      debugPrint(
        'LibraryFormScreen: No library provided - this is a create form',
      );
    }
  }

  void _populateForm() {
    final library = widget.library!;
    _nameController.text = library.name;
    _descriptionController.text = library.details;
    _imageUrlController.text = library.logoUrl ?? '';
    _isActive = library.isActive;
    debugPrint(
      'LibraryFormScreen: Populated form with library: ${library.name}',
    );
    debugPrint('LibraryFormScreen: Logo URL: ${library.logoUrl}');
    debugPrint('LibraryFormScreen: Has logo: ${library.hasLogo}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      debugPrint('LibraryFormScreen: Opening image picker...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      debugPrint('LibraryFormScreen: Image picker returned: ${image?.path}');

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            // For web, read bytes instead of using File
            image.readAsBytes().then((bytes) {
              if (mounted) {
                setState(() {
                  _selectedImageBytes = bytes;
                  _logoRemoved = false;
                });
              }
            });
          } else {
            _selectedImage = File(image.path);
            _logoRemoved = false; // Reset removal flag when selecting new image
          }
        });
        debugPrint('LibraryFormScreen: Image selected: ${image.path}');
      } else {
        debugPrint('LibraryFormScreen: No image selected');
      }
    } catch (e, stackTrace) {
      debugPrint('LibraryFormScreen: Error picking image: $e');
      debugPrint('LibraryFormScreen: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            // For web, read bytes instead of using File
            image.readAsBytes().then((bytes) {
              if (mounted) {
                setState(() {
                  _selectedImageBytes = bytes;
                  _logoRemoved = false;
                });
              }
            });
          } else {
            _selectedImage = File(image.path);
            _logoRemoved = false; // Reset removal flag when taking new picture
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorTakingPicture(e.toString())),
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _logoRemoved = true; // Mark that user wants to remove the logo
      // Clear the logo URL from the controller when removing
      _imageUrlController.clear();
    });
  }

  Future<void> _saveLibrary() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<LibraryProvider>();

      final libraryData = Library(
        id: widget.library?.id ?? '',
        name: _nameController.text.trim(),
        details: _descriptionController.text.trim(),
        logoUrl: _imageUrlController.text.trim(),
        isActive: _isActive,
        createdAt: widget.library?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.library == null) {
        final success = await provider.createLibrary(
          libraryData,
          logoFile: _selectedImage,
          logoBytes: _selectedImageBytes,
        );
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.libraryCreatedSuccessfully)),
            );
            Navigator.pop(context);
          } else {
            // Error is already handled by the provider
            return;
          }
        }
      } else {
        // If logo was removed, pass null explicitly; otherwise pass selected image or null to keep existing
        final success = await provider.updateLibrary(
          libraryData,
          logoFile: _logoRemoved ? null : _selectedImage,
          logoBytes: _logoRemoved ? null : _selectedImageBytes,
          removeLogo: _logoRemoved,
        );
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.libraryUpdatedSuccessfully)),
            );
            Navigator.pop(context);
          } else {
            // Error is already handled by the provider
            return;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.library == null
              ? localizations.createLibrary
              : localizations.editLibrary,
        ),
        actions: [
          if (widget.library != null)
            IconButton(
              onPressed: _isLoading ? null : () => _deleteLibrary(),
              icon: const Icon(Icons.delete),
              color: Colors.red,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildSectionCard(
                      title: localizations.basicInformation,
                      icon: Icons.info,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: '${localizations.libraryName} *',
                            border: const OutlineInputBorder(),
                            hintText: localizations.enterLibraryName,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.libraryNameRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: '${localizations.description} *',
                            border: const OutlineInputBorder(),
                            hintText: localizations.enterLibraryDetails,
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.detailsRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Logo Image Picker Section
                        Text(
                          localizations.libraryLogo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildImagePickerSection(),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveLibrary,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                widget.library == null
                                    ? localizations.createLibrary
                                    : localizations.updateLibrary,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePickerSection() {
    final logoUrl = widget.library?.logoUrl;
    final fullLogoUrl = logoUrl != null && logoUrl.isNotEmpty
        ? ApiConfig.buildImageUrl(logoUrl) ?? logoUrl
        : null;
    final hasImage =
        _selectedImage != null ||
        _selectedImageBytes != null ||
        (fullLogoUrl != null && fullLogoUrl.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (hasImage) ...[
            // Show selected image or existing logo
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                color: Colors.grey.shade200,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: _selectedImageBytes != null
                    ? Image.memory(
                        _selectedImageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      )
                    : _selectedImage != null
                    ? Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      )
                    : fullLogoUrl != null
                    ? Image.network(
                        fullLogoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
              ),
            ),
            // Remove image button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return ElevatedButton.icon(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete, size: 18),
                        label: Text(localizations.remove),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return ElevatedButton.icon(
                        onPressed: () {
                          debugPrint(
                            'LibraryFormScreen: Change button pressed',
                          );
                          _pickImage();
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(localizations.change),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            // Show image picker options
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.image, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.noLogoSelected,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: Text(localizations.gallery),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _takePicture,
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: Text(localizations.camera),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLibrary() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteLibrary),
        content: Text(localizations.areYouSureDeleteLibrary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final provider = context.read<LibraryProvider>();
        await provider.deleteLibrary();

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.libraryDeletedSuccessfully)),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
