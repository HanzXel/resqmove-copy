// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Location Service
//  lib/services/location_service.dart
//
//  Single source of truth for GPS in the app.
//  Used by:
//    • home_screen.dart          (patient submits request)
//    • driver_dashboard_screen   (driver's map position)
//    • driver_navigation_screen  (driver navigating to patient)
//
//  USAGE:
//    final result = await LocationService.instance.getCurrentLocation();
//    if (result.success) {
//      print(result.latitude);   // e.g. 10.3220
//      print(result.longitude);  // e.g. 123.8920
//      print(result.address);    // e.g. "Ayala Center, Cebu City"
//    } else {
//      print(result.errorMessage); // show to user
//    }
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// ── Location Result ───────────────────────────────────────────────────────────

class LocationResult {
  final bool success;
  final double latitude;
  final double longitude;
  final String? address;        // reverse-geocoded human-readable address
  final String? errorMessage;

  const LocationResult._({
    required this.success,
    this.latitude = 0,
    this.longitude = 0,
    this.address,
    this.errorMessage,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    String? address,
  }) =>
      LocationResult._(
        success: true,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

  factory LocationResult.failure(String message) =>
      LocationResult._(success: false, errorMessage: message);

  /// Fallback to Cebu City center if GPS unavailable
  factory LocationResult.fallback() => const LocationResult._(
        success: true,
        latitude: 10.3220,
        longitude: 123.8920,
        address: 'Cebu City, PH',
      );
}

// ── Location Service ──────────────────────────────────────────────────────────

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // ── Get current GPS position ───────────────────────────────────────────────
  //  1. Checks if location services are enabled on device
  //  2. Requests permission if not already granted
  //  3. Returns coordinates + a basic address label
  //  4. Falls back to Cebu City center if anything fails

  Future<LocationResult> getCurrentLocation({
    bool useFallbackOnError = true,
  }) async {
    try {
      // Check if GPS is turned on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log('Location services disabled');
        if (useFallbackOnError) return LocationResult.fallback();
        return LocationResult.failure(
          'Location services are disabled. Please turn on GPS.',
        );
      }

      // Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _log('Location permission denied');
          if (useFallbackOnError) return LocationResult.fallback();
          return LocationResult.failure(
            'Location permission denied. Please allow location access.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _log('Location permission permanently denied');
        if (useFallbackOnError) return LocationResult.fallback();
        return LocationResult.failure(
          'Location permission permanently denied. Enable it in Settings.',
        );
      }

      // Get position — balanced accuracy is faster than high, good enough for dispatch
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _log('Got position: ${position.latitude}, ${position.longitude}');

      // Build a simple address label from coordinates
      // We don't use geocoding package to keep dependencies minimal.
      // The backend can reverse-geocode properly if needed.
      final address = _buildAddressLabel(position.latitude, position.longitude);

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
    } on LocationServiceDisabledException {
      _log('LocationServiceDisabledException');
      if (useFallbackOnError) return LocationResult.fallback();
      return LocationResult.failure('GPS is turned off. Please enable it.');
    } on PermissionDeniedException catch (e) {
      _log('PermissionDeniedException: $e');
      if (useFallbackOnError) return LocationResult.fallback();
      return LocationResult.failure('Location permission denied.');
    } catch (e) {
      _log('Unexpected error: $e');
      if (useFallbackOnError) return LocationResult.fallback();
      return LocationResult.failure('Could not get location. Please try again.');
    }
  }

  // ── Stream position updates (for driver tracking) ──────────────────────────
  //  Call startTracking() to get a live stream of position updates.
  //  Used by DriverDashboardScreen to push location to server.

  Stream<Position> startTracking() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // only emit if moved 10+ meters
      ),
    );
  }

  // ── Check permission status without requesting ─────────────────────────────

  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ── Open device location settings ─────────────────────────────────────────

  Future<void> openSettings() => Geolocator.openLocationSettings();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Rough address label based on known Cebu City bounds.
  /// Replace with a proper geocoding package if needed.
  String _buildAddressLabel(double lat, double lng) {
    // Rough bounding box for Cebu City proper
    if (lat >= 10.28 && lat <= 10.38 && lng >= 123.85 && lng <= 123.93) {
      return 'Cebu City, PH';
    }
    // Mandaue
    if (lat >= 10.32 && lat <= 10.38 && lng >= 123.93 && lng <= 124.00) {
      return 'Mandaue City, PH';
    }
    // Lapu-Lapu
    if (lat >= 10.28 && lat <= 10.35 && lng >= 123.97 && lng <= 124.07) {
      return 'Lapu-Lapu City, PH';
    }
    // Generic fallback label with coords
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[LocationService] $msg');
  }
}
