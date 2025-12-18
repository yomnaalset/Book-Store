import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ads_provider.dart';
import '../../models/ad.dart' as ads_models;
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';

class AdFormScreen extends StatefulWidget {
  final ads_models.Ad? ad;

  const AdFormScreen({super.key, this.ad});

  @override
  State<AdFormScreen> createState() => _AdFormScreenState();
}

class _AdFormScreenState extends State<AdFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _selectedStatus = 'inactive';
  String _selectedAdType = 'general';
  String? _selectedDiscountCode;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  List<Map<String, dynamic>> _availableDiscountCodes = [];

  @override
  void initState() {
    super.initState();

    // Check permissions before initializing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });

    // Validate ad data to prevent dropdown errors
    _validateAdData();

    if (widget.ad != null) {
      debugPrint('DEBUG: AdFormScreen - Initializing with ad data:');
      debugPrint('  - title: ${widget.ad!.title}');
      debugPrint('  - adType: ${widget.ad!.adType}');
      debugPrint('  - discountCode: ${widget.ad!.discountCode}');
      debugPrint('  - status: ${widget.ad!.status}');

      _titleController.text = widget.ad!.title;
      _contentController.text = widget.ad!.content ?? '';
      _imageUrlController.text = widget.ad!.imageUrl ?? '';
      _selectedDiscountCode = widget.ad!.discountCode;

      // Validate and set status
      final status = widget.ad!.status;
      if (status == 'active' ||
          status == 'inactive' ||
          status == 'scheduled' ||
          status == 'expired') {
        _selectedStatus = status;
      } else {
        debugPrint(
          'DEBUG: Invalid status received: $status, defaulting to inactive',
        );
        _selectedStatus = 'inactive';
      }
      // Validate and set ad type
      final adType = widget.ad!.adType ?? 'general';
      if (adType == 'general' || adType == 'discount_code') {
        _selectedAdType = adType;
      } else {
        debugPrint(
          'DEBUG: Invalid adType received: $adType, defaulting to general',
        );
        _selectedAdType = 'general';
      }
      _startDate = widget.ad!.startDate;
      _endDate = widget.ad!.endDate;

      debugPrint(
        'DEBUG: AdFormScreen - Set _selectedAdType to: $_selectedAdType',
      );
    } else {
      // Set default dates for new ads
      _startDate = DateTime.now().add(const Duration(days: 1));
      _endDate = DateTime.now().add(const Duration(days: 30));
    }

    // Load discount codes only if editing an existing discount code ad
    if (widget.ad != null && widget.ad!.adType == 'discount_code') {
      _loadDiscountCodes();
    }
  }

  void _checkPermissions() {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.token == null) {
      _showPermissionError(
        'Authentication required. Please log in to manage advertisements.',
      );
      return;
    }

    if (!authProvider.isLibraryAdmin) {
      _showPermissionError(
        'Access denied. Only library administrators can manage advertisements.',
      );
      return;
    }
  }

  /// Validate and sanitize ad data to prevent dropdown errors
  void _validateAdData() {
    if (widget.ad == null) return;

    debugPrint('DEBUG: Validating ad data before form initialization');

    // Validate ad type
    final adType = widget.ad!.adType;
    if (adType != 'general' && adType != 'discount_code') {
      debugPrint(
        'WARNING: Invalid adType "$adType" detected, this may cause dropdown errors',
      );
    }

    // Validate status
    final status = widget.ad!.status;
    if (status != 'active' &&
        status != 'inactive' &&
        status != 'scheduled' &&
        status != 'expired') {
      debugPrint(
        'WARNING: Invalid status "$status" detected, this may cause dropdown errors',
      );
    }

    // Validate discount code
    final discountCode = widget.ad!.discountCode;
    if (discountCode != null && discountCode.isNotEmpty) {
      debugPrint('DEBUG: Ad has discount code: $discountCode');
    }
  }

  void _showPermissionError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate back after showing error
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void onAdTypeChanged(String newType) {
    debugPrint('DEBUG: Ad type changed to: $newType');
    setState(() {
      _selectedAdType = newType;
    });

    if (newType == 'discount_code') {
      debugPrint('DEBUG: Discount code ad type selected, fetching codes...');
      _loadDiscountCodes();
    } else {
      debugPrint('DEBUG: General ad type selected, clearing discount codes');
      setState(() {
        _availableDiscountCodes = [];
        _selectedDiscountCode = null;
      });
    }
  }

  Future<void> _loadDiscountCodes() async {
    try {
      debugPrint('DEBUG: Starting to load discount codes...');
      final adsProvider = context.read<AdsProvider>();
      final authProvider = context.read<AuthProvider>();

      // Check if user is authenticated
      if (authProvider.token == null) {
        debugPrint('DEBUG: No auth token available');
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.authenticationRequiredLoadDiscountCodes,
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if user has library admin permissions
      if (!authProvider.isLibraryAdmin) {
        debugPrint('DEBUG: User is not a library admin');
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.onlyLibraryAdminsAccessDiscountCodes),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Ensure provider has the current token
      debugPrint('DEBUG: Setting token for ads provider');
      adsProvider.setToken(authProvider.token);

      debugPrint('DEBUG: Calling getAvailableDiscountCodes...');
      final discountCodes = await adsProvider.getAvailableDiscountCodes();
      debugPrint('DEBUG: Received ${discountCodes.length} discount codes');

      if (mounted) {
        setState(() {
          _availableDiscountCodes = discountCodes;
        });
        debugPrint(
          'DEBUG: Updated _availableDiscountCodes with ${_availableDiscountCodes.length} codes',
        );

        // Show message if no discount codes are available
        if (discountCodes.isEmpty) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.noActiveDiscountCodesCreateFirst),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading discount codes: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.failedToLoadDiscountCodes}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, reset it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveAd() async {
    if (!_formKey.currentState!.validate()) return;

    final localizations = AppLocalizations.of(context);
    // Validate required date fields
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectStartDate),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectEndDate),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that end date is after start date
    if (_endDate!.isBefore(_startDate!) ||
        _endDate!.isAtSameMomentAs(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.endDateAfterStartDate),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adsProvider = context.read<AdsProvider>();
      final authProvider = context.read<AuthProvider>();

      // Ensure provider has the current token
      if (authProvider.token != null) {
        adsProvider.setToken(authProvider.token);
      }

      if (widget.ad == null) {
        // Create new ad
        debugPrint('DEBUG: Creating ad with ad_type: $_selectedAdType');
        final newAd = ads_models.Ad(
          id: 0, // Will be assigned by the server
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isEmpty
              ? null
              : _imageUrlController.text.trim(),
          status: _selectedStatus,
          adType: _selectedAdType,
          discountCode: _selectedDiscountCode,
          startDate:
              _startDate!, // Now guaranteed to be non-null due to validation
          endDate: _endDate!, // Now guaranteed to be non-null due to validation
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        debugPrint('DEBUG: Ad object created with adType: ${newAd.adType}');
        debugPrint('DEBUG: Ad toJson: ${newAd.toJson(includeId: false)}');
        await adsProvider.createAd(newAd);
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.advertisementCreatedSuccessfully),
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        // Update existing ad
        debugPrint('DEBUG: Updating ad with ad_type: $_selectedAdType');
        final updatedAd = widget.ad!.copyWith(
          title: _titleController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isEmpty
              ? null
              : _imageUrlController.text.trim(),
          status: _selectedStatus,
          adType: _selectedAdType,
          discountCode: _selectedDiscountCode,
          startDate:
              _startDate!, // Now guaranteed to be non-null due to validation
          endDate: _endDate!, // Now guaranteed to be non-null due to validation
          updatedAt: DateTime.now(),
          content: _contentController.text.trim(),
        );
        debugPrint('DEBUG: Ad object updated with adType: ${updatedAd.adType}');
        debugPrint('DEBUG: Ad toJson: ${updatedAd.toJson(includeId: true)}');
        await adsProvider.updateAd(updatedAd);
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.advertisementUpdatedSuccessfully),
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorColon} ${e.toString()}'),
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
          widget.ad == null
              ? localizations.createAdvertisement
              : localizations.editAdvertisement,
        ),
        actions: [
          if (widget.ad != null)
            IconButton(
              onPressed: _isLoading ? null : () => _deleteAd(),
              icon: const Icon(Icons.delete),
              color: Colors.red,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '${localizations.titleLabel} *',
                  border: const OutlineInputBorder(),
                  hintText: localizations.enterAdvertisementTitle,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.titleRequired;
                  }
                  if (value.trim().length < 3) {
                    return localizations.titleMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Content
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: '${localizations.contentLabel} *',
                  border: const OutlineInputBorder(),
                  hintText: localizations.enterAdvertisementContent,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.contentRequired;
                  }
                  if (value.trim().length < 10) {
                    return localizations.contentMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Image URL
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: localizations.imageUrlOptional,
                  border: const OutlineInputBorder(),
                  hintText: localizations.enterImageUrl,
                ),
              ),
              const SizedBox(height: 16),

              // Ad Type
              DropdownButtonFormField<String>(
                key: ValueKey('ad_type_$_selectedAdType'),
                initialValue:
                    (_selectedAdType == 'general' ||
                        _selectedAdType == 'discount_code')
                    ? _selectedAdType
                    : 'general',
                decoration: InputDecoration(
                  labelText: '${localizations.adTypeLabel} *',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'general',
                    child: Text(localizations.generalAdvertisement),
                  ),
                  DropdownMenuItem(
                    value: 'discount_code',
                    child: Text(localizations.discountCodeAdvertisement),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onAdTypeChanged(value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Discount Code (only show if ad type is discount_code)
              if (_selectedAdType == 'discount_code') ...[
                Builder(
                  builder: (context) {
                    debugPrint(
                      'DEBUG: Rendering discount code dropdown with ${_availableDiscountCodes.length} codes',
                    );
                    return DropdownButtonFormField<String>(
                      key: ValueKey('discount_code_$_selectedDiscountCode'),
                      initialValue:
                          _availableDiscountCodes.any(
                            (code) => code['code'] == _selectedDiscountCode,
                          )
                          ? _selectedDiscountCode
                          : null,
                      decoration: InputDecoration(
                        labelText: '${localizations.discountCodeLabel} *',
                        border: const OutlineInputBorder(),
                        hintText: localizations.selectDiscountCodeHint,
                      ),
                      items: _availableDiscountCodes.isEmpty
                          ? [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(
                                  localizations.noActiveDiscountCodesFound,
                                ),
                              ),
                            ]
                          : _availableDiscountCodes.map((code) {
                              final discountPercentage =
                                  code['discount_percentage']?.toString() ??
                                  '0';
                              final expirationDate =
                                  code['expiration_date'] != null
                                  ? DateTime.parse(
                                      code['expiration_date'],
                                    ).toLocal()
                                  : null;
                              final expirationText = expirationDate != null
                                  ? ' (Expires: ${expirationDate.day}/${expirationDate.month}/${expirationDate.year})'
                                  : '';

                              return DropdownMenuItem<String>(
                                value: code['code'],
                                child: Text(
                                  '${code['code']} - $discountPercentage%$expirationText',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDiscountCode = value;
                        });
                      },
                      validator: (value) {
                        if (_selectedAdType == 'discount_code') {
                          if (value == null || value.isEmpty) {
                            return localizations
                                .discountCodeRequiredForDiscountAds;
                          }
                        }
                        return null;
                      },
                    );
                  },
                ),
                // Add helpful message when no discount codes are available
                if (_availableDiscountCodes.isEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            localizations.noActiveDiscountCodesInfo,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Status
              DropdownButtonFormField<String>(
                key: ValueKey('status_$_selectedStatus'),
                initialValue:
                    (_selectedStatus == 'active' ||
                        _selectedStatus == 'inactive' ||
                        _selectedStatus == 'scheduled' ||
                        _selectedStatus == 'expired')
                    ? _selectedStatus
                    : 'inactive',
                decoration: InputDecoration(
                  labelText: '${localizations.statusLabel} *',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'inactive',
                    child: Text(localizations.advertisementStatusInactive),
                  ),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text(localizations.advertisementStatusActive),
                  ),
                  DropdownMenuItem(
                    value: 'scheduled',
                    child: Text(localizations.advertisementStatusScheduled),
                  ),
                  DropdownMenuItem(
                    value: 'expired',
                    child: Text(localizations.advertisementStatusExpired),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date Range
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localizations.startDateLabel} *',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _startDate == null
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 8),
                                Text(
                                  _startDate != null
                                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                      : localizations.selectStartDate,
                                  style: TextStyle(
                                    color: _startDate == null
                                        ? Colors.red
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_startDate == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              localizations.startDateRequired,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localizations.endDateLabel} *',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _endDate == null
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 8),
                                Text(
                                  _endDate != null
                                      ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                      : localizations.selectEndDate,
                                  style: TextStyle(
                                    color: _endDate == null ? Colors.red : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_endDate == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              localizations.endDateRequired,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAd,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          widget.ad == null
                              ? localizations.createAdvertisement
                              : localizations.updateAdvertisement,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAd() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteAdvertisement),
        content: Text(localizations.deleteAdvertisementConfirmation),
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
        final adsProvider = context.read<AdsProvider>();
        await adsProvider.deleteAd(widget.ad!.id);

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.advertisementDeletedSuccessfully),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localizations.errorColon} ${e.toString()}'),
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
