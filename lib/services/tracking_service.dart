// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Tracking Service
//  lib/services/tracking_service.dart
//
//  Handles real-time ambulance location tracking for the patient side.
//  Polls the backend on an interval until the trip is completed/cancelled.
//
//  ENDPOINTS YOUR CLASSMATE NEEDS TO IMPLEMENT:
//    GET  /requests/:id/tracking
//         returns: {
//           driver_location: { latitude, longitude, timestamp },
//           status: 'accepted'|'in_progress'|'completed',
//           eta_minutes: 5
//         }
//
//    POST /driver/location
//         body: { latitude, longitude, request_id? }
//         returns: { success: true }
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/models.dart';

// ── Tracking Snapshot ─────────────────────────────────────────────────────────

class TrackingSnapshot {
  final DriverLocation? driverLocation;
  final RequestStatus status;
  final int? etaMinutes;
  final DateTime fetchedAt;

  const TrackingSnapshot({
    this.driverLocation,
    required this.status,
    this.etaMinutes,
    required this.fetchedAt,
  });

  factory TrackingSnapshot.fromJson(Map<String, dynamic> json) {
    return TrackingSnapshot(
      driverLocation: json['driver_location'] != null
          ? DriverLocation.fromJson(json['driver_location'] as Map<String, dynamic>)
          : null,
      status: RequestStatusX.fromString(json['status']?.toString()),
      etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
      fetchedAt: DateTime.now(),
    );
  }

  bool get isTerminal =>
      status == RequestStatus.completed || status == RequestStatus.cancelled;
}

// ── Tracking Service ──────────────────────────────────────────────────────────

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  final ApiClient _client = ApiClient.instance;

  Timer? _pollTimer;
  final StreamController<TrackingSnapshot> _streamController =
      StreamController<TrackingSnapshot>.broadcast();

  /// Live stream of tracking updates — subscribe in tracking_screen.dart
  Stream<TrackingSnapshot> get trackingStream => _streamController.stream;

  bool get isTracking => _pollTimer?.isActive ?? false;

  // ── Start polling for a request ────────────────────────────────────────────
  //  Polls every [intervalSeconds] seconds.
  //  Automatically stops when status is completed or cancelled.

  void startTracking(String requestId, {int intervalSeconds = 5}) {
    stopTracking();

    _log('Tracking started for request $requestId');

    _fetchAndEmit(requestId);
    _pollTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _fetchAndEmit(requestId),
    );
  }

  // ── Stop polling ───────────────────────────────────────────────────────────

  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _log('Tracking stopped');
  }

  // ── One-shot fetch (no polling) ────────────────────────────────────────────

  Future<TrackingSnapshot?> fetchOnce(String requestId) async {
    try {
      return await _fetchSnapshot(requestId);
    } catch (_) {
      return null;
    }
  }

  // ── Private fetch + emit ───────────────────────────────────────────────────

  Future<void> _fetchAndEmit(String requestId) async {
    try {
      final snapshot = await _fetchSnapshot(requestId);
      _streamController.add(snapshot);

      if (snapshot.isTerminal) {
        _log('Trip terminal (${snapshot.status.label}) — stopping tracker');
        stopTracking();
      }
    } catch (e) {
      _log('Fetch error: $e');
    }
  }

  Future<TrackingSnapshot> _fetchSnapshot(String requestId) async {
    if (_mockMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return TrackingSnapshot(
        driverLocation: null,
        status: RequestStatus.pending,
        etaMinutes: null,
        fetchedAt: DateTime.now(),
      );
    }

    final response = await _client.get('/requests/$requestId/tracking');
    return TrackingSnapshot.fromJson(response.data ?? {});
  }

  // ── Driver location push (driver → server) ─────────────────────────────────

  Future<void> pushDriverLocation({
    required double latitude,
    required double longitude,
    String? activeRequestId,
  }) async {
    try {
      if (_mockMode) {
        _log('Driver location push (mock): $latitude, $longitude');
        return;
      }

      await _client.post('/driver/location', body: {
        'latitude': latitude,
        'longitude': longitude,
        if (activeRequestId != null) 'request_id': activeRequestId,
      });
    } catch (e) {
      _log('Location push error: $e');
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  void dispose() {
    stopTracking();
    _streamController.close();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[TrackingService] $msg');
  }
}

// ── Toggle mock mode ──────────────────────────────────────────────────────────
const bool _mockMode = true;
