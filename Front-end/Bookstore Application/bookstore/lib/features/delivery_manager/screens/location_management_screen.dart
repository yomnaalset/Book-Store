import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readgo/core/constants/app_colors.dart';
import 'package:readgo/core/services/location_management_service.dart';
import 'package:readgo/core/services/location_service.dart';
import 'package:readgo/core/localization/app_localizations.dart';
import 'package:readgo/features/auth/providers/auth_provider.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final _addressController = TextEditingController();
  bool _isLoading = false;
  bool _isUpdating = false;
  Map<String, dynamic>? _currentLocation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.pleaseLogInToManageLocation;
          _isLoading = false;
        });
        return;
      }

      final result = await LocationManagementService.getCurrentLocation(
        token: token,
      );

      if (result['success'] && mounted) {
        setState(() {
          _currentLocation = result['data']['location'];
          _addressController.text = _currentLocation?['address'] ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = result['error'] ?? localizations.failedToLoadLocation;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.errorLoadingLocation(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateLocationFromGPS() async {
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      final locationService = Provider.of<LocationService>(
        context,
        listen: false,
      );
      final position = await locationService.getCurrentLocation();

      if (position != null && mounted) {
        await _updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: _addressController.text.trim(),
        );
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.failedToGetGpsLocation;
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.errorGettingGpsLocation(e.toString());
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateLocation({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.pleaseLogInToUpdateLocation;
          _isUpdating = false;
        });
        return;
      }

      final result = await LocationManagementService.updateLocation(
        token: token,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      if (result['success'] && mounted) {
        setState(() {
          _currentLocation = result['data']['location'];
          _isUpdating = false;
        });

        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.locationUpdatedSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              result['error'] ?? localizations.failedToUpdateLocation;
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.errorUpdatingLocationWithError(
            e.toString(),
          );
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateAddressOnly() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      final localizations = AppLocalizations.of(context);
      setState(() {
        _errorMessage = localizations.pleaseEnterAnAddress;
      });
      return;
    }

    await _updateLocation(address: address);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          localizations.manageLocation,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Location Status
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
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.currentLocationStatus,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_currentLocation != null) ...[
                            _buildLocationInfo(
                              localizations.addressLabel,
                              _currentLocation!['address'] ??
                                  localizations.notSet,
                            ),
                            _buildLocationInfo(
                              localizations.coordinatesLabel,
                              _currentLocation!['latitude'] != null &&
                                      _currentLocation!['longitude'] != null
                                  ? '${_currentLocation!['latitude']}, ${_currentLocation!['longitude']}'
                                  : localizations.notSet,
                            ),
                            _buildLocationInfo(
                              localizations.lastUpdated,
                              _currentLocation!['location_updated_at'] != null
                                  ? DateTime.parse(
                                      _currentLocation!['location_updated_at'],
                                    ).toString()
                                  : localizations.never,
                            ),
                          ] else ...[
                            Text(
                              localizations.noLocationSet,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Update Location Section
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
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.updateLocation,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),

                          // Address Input
                          TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: localizations.addressOptional,
                              hintText: localizations
                                  .enterAddressOrLocationDescription,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.location_on),
                            ),
                            maxLines: 3,
                          ),

                          const SizedBox(height: 16),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isUpdating
                                      ? null
                                      : _updateLocationFromGPS,
                                  icon: _isUpdating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: Text(
                                    _isUpdating
                                        ? localizations.gettingLocation
                                        : localizations.useGpsLocation,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isUpdating
                                      ? null
                                      : _updateAddressOnly,
                                  icon: const Icon(Icons.save),
                                  label: Text(localizations.saveAddress),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.instructions,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• ${localizations.instructionUseGpsLocation}\n'
                            '• ${localizations.instructionEnterAddressManually}\n'
                            '• ${localizations.instructionLocationHelpsCustomers}\n'
                            '• ${localizations.instructionAdminsMonitorLocations}\n'
                            '• ${localizations.instructionLocationDataOptimization}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
