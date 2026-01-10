import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../providers/library_manager/authors_provider.dart';
import '../../../models/author.dart';
import '../../../../../../core/localization/app_localizations.dart';
import '../../../../auth/providers/auth_provider.dart';

class AuthorFormScreen extends StatefulWidget {
  final Author? author;

  const AuthorFormScreen({super.key, this.author});

  @override
  State<AuthorFormScreen> createState() => _AuthorFormScreenState();
}

class _AuthorFormScreenState extends State<AuthorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _biographyController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _nationalityController = TextEditingController();

  DateTime? _birthDate;
  DateTime? _deathDate;
  File? _selectedImage; // For mobile/desktop
  Uint8List? _selectedImageBytes; // For web
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.author != null) {
      _populateForm();
    }
  }

  void _populateForm() {
    final author = widget.author!;
    _nameController.text = author.name;
    _biographyController.text = author.biography ?? '';
    _imageUrlController.text = author.photo ?? '';
    _nationalityController.text = author.country ?? '';
    _birthDate = author.birthDate != null
        ? DateTime.tryParse(author.birthDate!)
        : null;
    _deathDate = author.deathDate != null
        ? DateTime.tryParse(author.deathDate!)
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _biographyController.dispose();
    _imageUrlController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1800),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _selectDeathDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deathDate ?? DateTime.now(),
      firstDate: _birthDate ?? DateTime(1800),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _deathDate) {
      setState(() {
        _deathDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
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
                _imageUrlController.clear(); // Clear URL when image is selected
              });
            }
          });
        } else {
          _selectedImage = File(image.path);
          _imageUrlController.clear(); // Clear URL when image is selected
        }
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
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
                _imageUrlController.clear(); // Clear URL when image is selected
              });
            }
          });
        } else {
          _selectedImage = File(image.path);
          _imageUrlController.clear(); // Clear URL when image is selected
        }
      });
    }
  }

  Future<void> _saveAuthor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<AuthorsProvider>();
      final authProvider = context.read<AuthProvider>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Ensure the provider has the latest token
      if (authProvider.token != null) {
        provider.setToken(authProvider.token);
        debugPrint(
          'DEBUG: Author form - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
        );
      } else {
        debugPrint('DEBUG: Author form - No token available from AuthProvider');
        final localizations = AppLocalizations.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(localizations.authenticationRequired),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final authorData = Author(
        id: widget.author?.id ?? '',
        name: _nameController.text.trim(),
        biography: _biographyController.text.trim().isEmpty
            ? null
            : _biographyController.text.trim(),
        photo: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        country: _nationalityController.text.trim().isEmpty
            ? null
            : _nationalityController.text.trim(),
        birthDate: _birthDate?.toIso8601String(),
        deathDate: _deathDate?.toIso8601String(),
        isActive: true, // Always set to active
        createdAt: widget.author?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final localizations = AppLocalizations.of(context);
      if (widget.author == null) {
        await provider.createAuthor(
          authorData,
          photoFile: _selectedImage,
          photoBytes: _selectedImageBytes,
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(localizations.authorCreatedSuccessfully)),
          );
        }
      } else {
        debugPrint(
          'DEBUG: Author form - Updating author with data: ${authorData.toJson()}',
        );
        final updatedAuthor = await provider.updateAuthor(
          authorData,
          photoFile: _selectedImage,
          photoBytes: _selectedImageBytes,
        );
        if (mounted) {
          if (updatedAuthor != null) {
            debugPrint('DEBUG: Author form - Author updated successfully');
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text(localizations.authorUpdatedSuccessfully)),
            );
          } else {
            debugPrint(
              'DEBUG: Author form - Author update failed: ${provider.error}',
            );
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  provider.error ?? localizations.failedToUpdateAuthor,
                ),
                backgroundColor: Colors.red,
              ),
            );
            return; // Don't navigate back if update failed
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        String errorMessage = localizations.failedToSaveAuthor;
        if (e.toString().contains('401')) {
          errorMessage = localizations.authenticationRequiredPleaseLogInAgain;
        } else if (e.toString().contains('400')) {
          errorMessage = localizations.invalidDataPleaseCheckInput;
        } else if (e.toString().contains('500')) {
          errorMessage = localizations.serverError;
        } else {
          errorMessage = '${localizations.error}: ${e.toString()}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.author == null
              ? localizations.addAuthor
              : localizations.editAuthor,
        ),
        actions: [
          if (widget.author != null)
            IconButton(
              onPressed: _isLoading ? null : () => _deleteAuthor(),
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, color: Colors.purple),
                                const SizedBox(width: 12),
                                Text(
                                  localizations.authorInformation,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Name Field
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: '${localizations.authorName} *',
                                border: const OutlineInputBorder(),
                                hintText: localizations.enterAuthorName,
                                prefixIcon: const Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return localizations.authorNameRequired;
                                }
                                if (value.trim().length < 2) {
                                  return localizations.authorNameMinLength;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Biography Field
                            TextFormField(
                              controller: _biographyController,
                              decoration: InputDecoration(
                                labelText: localizations.biography,
                                border: const OutlineInputBorder(),
                                hintText: localizations.enterAuthorBiography,
                                prefixIcon: const Icon(Icons.description),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 4,
                            ),
                            const SizedBox(height: 16),

                            // Nationality Field
                            TextFormField(
                              controller: _nationalityController,
                              decoration: InputDecoration(
                                labelText: localizations.nationality,
                                border: const OutlineInputBorder(),
                                hintText: localizations.enterAuthorNationality,
                                prefixIcon: const Icon(Icons.public),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Image Selection
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.authorPhoto,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Image Preview
                                if (_selectedImage != null || _selectedImageBytes != null) ...[
                                  Container(
                                    height: 120,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _selectedImageBytes != null
                                          ? Image.memory(
                                              _selectedImageBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : _selectedImage != null
                                              ? Image.file(
                                                  _selectedImage!,
                                                  fit: BoxFit.cover,
                                                )
                                              : const Icon(Icons.person, size: 60),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // Image Selection Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickImage,
                                        icon: const Icon(Icons.photo_library),
                                        label: Text(localizations.gallery),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _takePhoto,
                                        icon: const Icon(Icons.camera_alt),
                                        label: Text(localizations.camera),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Image URL Field (Alternative)
                                TextFormField(
                                  controller: _imageUrlController,
                                  decoration: InputDecoration(
                                    labelText: localizations.orEnterImageUrl,
                                    border: const OutlineInputBorder(),
                                    hintText: localizations.enterImageUrl,
                                    prefixIcon: const Icon(Icons.link),
                                  ),
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      setState(() {
                                        _selectedImage = null; // Clear selected image when URL is entered
                                        _selectedImageBytes = null; // Clear bytes too
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Birth Date Field
                            InkWell(
                              onTap: _selectBirthDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: localizations.birthDate,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _birthDate != null
                                      ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                      : localizations.selectBirthDate,
                                  style: TextStyle(
                                    color: _birthDate != null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                            ),

                            // Clear birth date button
                            if (_birthDate != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _birthDate = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: Text(localizations.clearBirthDate),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Death Date Field
                            InkWell(
                              onTap: _selectDeathDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: localizations.deathDate,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.event),
                                ),
                                child: Text(
                                  _deathDate != null
                                      ? '${_deathDate!.day}/${_deathDate!.month}/${_deathDate!.year}'
                                      : localizations.selectDeathDate,
                                  style: TextStyle(
                                    color: _deathDate != null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color
                                        : Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                            ),

                            // Clear death date button
                            if (_deathDate != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _deathDate = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 16),
                                label: Text(localizations.clearDeathDate),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAuthor,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                widget.author == null
                                    ? localizations.addAuthor
                                    : localizations.updateAuthor,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _deleteAuthor() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.deleteAuthor),
        content: Text(
            localizations.deleteAuthorConfirmation(widget.author!.name),
        ),
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
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final provider = context.read<AuthorsProvider>();
        final authProvider = context.read<AuthProvider>();
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        // Ensure the provider has the latest token
        if (authProvider.token != null) {
          provider.setToken(authProvider.token);
        }

        await provider.deleteAuthor(int.parse(widget.author!.id));

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(localizations.authorDeletedSuccessfully)),
          );
          navigator.pop();
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          String errorMessage = localizations.failedToDeleteAuthor;
          if (e.toString().contains('401')) {
            errorMessage = localizations.authenticationRequiredPleaseLogInAgain;
          } else if (e.toString().contains('book(s) assigned to it')) {
            errorMessage = localizations.cannotDeleteAuthorWithBooks;
          } else {
            errorMessage = '${localizations.error}: ${e.toString()}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
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
  }
}
