import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bookstore/core/constants/app_colors.dart';
import 'package:bookstore/core/services/location_management_service.dart';
import 'package:bookstore/core/services/location_service.dart';
import 'package:bookstore/features/auth/providers/auth_provider.dart';

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
        setState(() {
          _errorMessage = 'Please log in to manage your location';
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
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load location';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading location: ${e.toString()}';
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
        setState(() {
          _errorMessage =
              'Failed to get GPS location. Please check location permissions.';
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error getting GPS location: ${e.toString()}';
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
        setState(() {
          _errorMessage = 'Please log in to update your location';
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to update location';
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error updating location: ${e.toString()}';
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateAddressOnly() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an address';
      });
      return;
    }

    await _updateLocation(address: address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Location'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Location Status
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Location Status',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_currentLocation != null) ...[
                            _buildLocationInfo(
                              'Address',
                              _currentLocation!['address'] ?? 'Not set',
                            ),
                            _buildLocationInfo(
                              'Coordinates',
                              _currentLocation!['latitude'] != null &&
                                      _currentLocation!['longitude'] != null
                                  ? '${_currentLocation!['latitude']}, ${_currentLocation!['longitude']}'
                                  : 'Not set',
                            ),
                            _buildLocationInfo(
                              'Last Updated',
                              _currentLocation!['location_updated_at'] != null
                                  ? DateTime.parse(
                                      _currentLocation!['location_updated_at'],
                                    ).toString()
                                  : 'Never',
                            ),
                          ] else ...[
                            Text(
                              'No location set',
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
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Location',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),

                          // Address Input
                          TextField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address (Optional)',
                              hintText:
                                  'Enter your address or location description',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
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
                                        ? 'Getting Location...'
                                        : 'Use GPS Location',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.white,
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
                                  label: const Text('Save Address'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: AppColors.white,
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
                            'Instructions',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '• Use "Use GPS Location" to automatically get your current coordinates\n'
                            '• Enter an address manually for better location description\n'
                            '• Your location helps customers track their orders\n'
                            '• Admins can monitor delivery manager locations\n'
                            '• Location data is used for delivery optimization',
                            style: TextStyle(fontSize: 14),
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
