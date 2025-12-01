import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService extends ChangeNotifier {
  bool _isLocationEnabled = false;
  bool _hasLocationPermission = false;
  Position? _currentPosition;
  String _locationStatus = 'Unknown';

  // Getters
  bool get isLocationEnabled => _isLocationEnabled;
  bool get hasLocationPermission => _hasLocationPermission;
  Position? get currentPosition => _currentPosition;
  String get locationStatus => _locationStatus;

  LocationService() {
    _initializeLocationService();
  }

  // Initialize location service
  Future<void> _initializeLocationService() async {
    await _checkLocationPermission();
    await _checkLocationService();
    _updateLocationStatus();
  }

  // Check if location services are enabled
  Future<bool> _checkLocationService() async {
    try {
      _isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      notifyListeners();
      return _isLocationEnabled;
    } catch (e) {
      debugPrint('Error checking location service: $e');
      _isLocationEnabled = false;
      notifyListeners();
      return false;
    }
  }

  // Check location permissions
  Future<bool> _checkLocationPermission() async {
    try {
      final status = await Permission.location.status;
      _hasLocationPermission = status.isGranted;
      notifyListeners();
      return _hasLocationPermission;
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      _hasLocationPermission = false;
      notifyListeners();
      return false;
    }
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      _hasLocationPermission = status.isGranted;
      notifyListeners();
      _updateLocationStatus();
      return _hasLocationPermission;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      _hasLocationPermission = false;
      notifyListeners();
      _updateLocationStatus();
      return false;
    }
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      if (!_hasLocationPermission) {
        final granted = await requestLocationPermission();
        if (!granted) {
          _locationStatus = 'Permission denied';
          notifyListeners();
          return null;
        }
      }

      if (!_isLocationEnabled) {
        _locationStatus = 'Location services disabled';
        notifyListeners();
        return null;
      }

      _locationStatus = 'Getting location...';
      notifyListeners();

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _locationStatus = 'Location obtained';
      notifyListeners();

      return position;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      _locationStatus = 'Error getting location: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  // Start location tracking
  Future<void> startLocationTracking() async {
    try {
      if (!_hasLocationPermission || !_isLocationEnabled) {
        await _initializeLocationService();
        if (!_hasLocationPermission || !_isLocationEnabled) {
          _locationStatus =
              'Cannot start tracking - permission or service disabled';
          notifyListeners();
          return;
        }
      }

      _locationStatus = 'Location tracking started';
      notifyListeners();

      // Start listening to location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          _currentPosition = position;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Location tracking error: $error');
          _locationStatus = 'Tracking error: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      _locationStatus = 'Error starting tracking: ${e.toString()}';
      notifyListeners();
    }
  }

  // Stop location tracking
  Future<void> stopLocationTracking() async {
    try {
      _locationStatus = 'Location tracking stopped';
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping location tracking: $e');
      _locationStatus = 'Error stopping tracking: ${e.toString()}';
      notifyListeners();
    }
  }

  // Open location settings
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
      // Refresh status after opening settings
      await Future.delayed(const Duration(seconds: 1));
      await _checkLocationService();
      await _checkLocationPermission();
      _updateLocationStatus();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
    }
  }

  // Open app settings for permission management
  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  // Update location status based on current state
  void _updateLocationStatus() {
    if (!_isLocationEnabled) {
      _locationStatus = 'Location services disabled';
    } else if (!_hasLocationPermission) {
      _locationStatus = 'Location permission denied';
    } else if (_currentPosition != null) {
      _locationStatus = 'Location available';
    } else {
      _locationStatus = 'Ready to get location';
    }
    notifyListeners();
  }

  // Get formatted location string
  String getFormattedLocation() {
    if (_currentPosition == null) {
      return 'No location available';
    }

    return 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, '
        'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  // Get distance between two points in meters
  double getDistanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Check if location is within delivery range (example: 5km)
  bool isWithinDeliveryRange(
    double targetLatitude,
    double targetLongitude, {
    double maxDistanceKm = 5.0,
  }) {
    if (_currentPosition == null) return false;

    final distance = getDistanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLatitude,
      targetLongitude,
    );

    return distance <= (maxDistanceKm * 1000); // Convert km to meters
  }
}
