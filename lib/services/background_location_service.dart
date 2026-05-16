// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Background Location Service
//  lib/services/background_location_service.dart
//
//  Keeps pushing the driver's GPS coordinates to the backend even when the
//  app is in the background or screen is off, using flutter_background_service.
//
//  Call start() when a driver accepts a trip, stop() when it ends.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Entry point for the background isolate ────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _backgroundServiceEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  String? requestId;

  service.on('set_request_id').listen((data) {
    requestId = data?['request_id']?.toString();
    if (kDebugMode) debugPrint('[BgLocation] Tracking request: \$requestId');
  });

  service.on('stop').listen((_) {
    service.stopSelf();
  });

  // Push GPS every 12 seconds
  Timer.periodic(const Duration(seconds: 12), (_) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      service.invoke('location_update', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'request_id': requestId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[BgLocation] GPS error: \$e');
    }
  });
}

class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService instance = BackgroundLocationService._();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  StreamSubscription? _locationSub;
  bool _configured = false;

  /// [onLocation] receives {latitude, longitude, request_id, timestamp} updates.
  Future<void> init({
    required void Function(Map<String, dynamic>) onLocation,
  }) async {
    if (_configured) return;
    _configured = true;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _backgroundServiceEntryPoint,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'resqmove_bg_location',
        initialNotificationTitle: 'ResQMove — Trip Active',
        initialNotificationContent: 'Tracking your location for the active trip.',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _backgroundServiceEntryPoint,
        onBackground: _iosBackgroundHandler,
      ),
    );

    _locationSub = _service.on('location_update').listen((data) {
      if (data != null) onLocation(Map<String, dynamic>.from(data));
    });
  }

  Future<void> start({required String requestId}) async {
    final hasPerm = await _checkPermissions();
    if (!hasPerm) {
      if (kDebugMode) debugPrint('[BgLocation] Permission denied — cannot start background tracking');
      return;
    }

    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
    _service.invoke('set_request_id', {'request_id': requestId});
    if (kDebugMode) debugPrint('[BgLocation] Started for request \$requestId');
  }

  Future<void> stop() async {
    _service.invoke('stop');
    if (kDebugMode) debugPrint('[BgLocation] Stopped');
  }

  Future<bool> get isRunning => _service.isRunning();

  void dispose() {
    _locationSub?.cancel();
  }

  Future<bool> _checkPermissions() async {
    var locationStatus = await Permission.location.status;
    if (locationStatus.isDenied) {
      locationStatus = await Permission.location.request();
    }
    if (!locationStatus.isGranted) return false;

    // Background location requires a separate permission on Android 10+
    var bgStatus = await Permission.locationAlways.status;
    if (bgStatus.isDenied) {
      bgStatus = await Permission.locationAlways.request();
    }
    return bgStatus.isGranted;
  }
}

@pragma('vm:entry-point')
Future<bool> _iosBackgroundHandler(ServiceInstance service) async {
  return true;
}
