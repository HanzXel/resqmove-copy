// Background location service — temporarily stubbed out
// flutter_background_service is disabled until notification permission flow is fixed.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService instance = BackgroundLocationService._();

  StreamSubscription<Position>? _positionSub;
  void Function(Map<String, dynamic>)? _onLocation;

  Future<void> init({required void Function(Map<String, dynamic>) onLocation}) async {
    _onLocation = onLocation;
  }

  Future<void> start({required String requestId}) async {
    final hasPerm = await _checkPermissions();
    if (!hasPerm) {
      if (kDebugMode) debugPrint('[BgLocation] Permission denied');
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      _onLocation?.call({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'request_id': requestId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    if (kDebugMode) debugPrint('[BgLocation] Started for request $requestId');
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    if (kDebugMode) debugPrint('[BgLocation] Stopped');
  }

  Future<bool> get isRunning async => _positionSub != null;

  void dispose() {
    _positionSub?.cancel();
  }

  Future<bool> _checkPermissions() async {
    var status = await Permission.location.status;
    if (status.isDenied) status = await Permission.location.request();
    return status.isGranted;
  }
}
