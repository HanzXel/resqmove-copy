// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Tracking Service
//  lib/services/tracking_service.dart
//
//  Patient-side tracking: Socket.io push when the driver updates location, plus
//  slow HTTP polling as a fallback. Mock mode uses short polling only.
//
//  Backend: GET /requests/:id/tracking, POST /driver/location, Socket.io room
//  `track:<requestId>` with event `tracking_update`.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../config/app_config.dart';
import '../models/models.dart';
import 'api_client.dart';

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
          ? DriverLocation.fromJson(
              json['driver_location'] as Map<String, dynamic>,
            )
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
  socket_io.Socket? _socket;

  final StreamController<TrackingSnapshot> _streamController =
      StreamController<TrackingSnapshot>.broadcast();

  Stream<TrackingSnapshot> get trackingStream => _streamController.stream;

  bool get isTracking =>
      (_pollTimer?.isActive ?? false) || (_socket?.connected ?? false);

  /// [backupPollSeconds]: HTTP fallback when socket is unavailable.
  void startTracking(String requestId, {int backupPollSeconds = 25}) {
    stopTracking();

    _log('Tracking started for request $requestId');

    unawaited(_fetchAndEmit(requestId));

    if (AppConfig.useMockApi) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_fetchAndEmit(requestId)),
      );
      return;
    }

    unawaited(_connectSocket(requestId));
    _pollTimer = Timer.periodic(
      Duration(seconds: backupPollSeconds),
      (_) => unawaited(_fetchAndEmit(requestId)),
    );
  }

  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _disconnectSocket();
    _log('Tracking stopped');
  }

  Future<TrackingSnapshot?> fetchOnce(String requestId) async {
    try {
      return await _fetchSnapshot(requestId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchAndEmit(String requestId) async {
    try {
      final snapshot = await _fetchSnapshot(requestId);
      if (!_streamController.isClosed) {
        _streamController.add(snapshot);
      }

      if (snapshot.isTerminal) {
        _log('Trip terminal (${snapshot.status.label}) — stopping tracker');
        stopTracking();
      }
    } catch (e) {
      _log('Fetch error: $e');
    }
  }

  Future<TrackingSnapshot> _fetchSnapshot(String requestId) async {
    if (AppConfig.useMockApi) {
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

  String _socketOrigin() {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final port = base.hasPort ? base.port : (base.scheme == 'https' ? 443 : 80);
    return '${base.scheme}://${base.host}:$port';
  }

  Future<void> _connectSocket(String requestId) async {
    _disconnectSocket();
    final token = _client.accessToken;
    if (token == null || token.isEmpty) {
      _log('No access token — socket tracking skipped');
      return;
    }

    try {
      _socket = socket_io.io(
        _socketOrigin(),
        socket_io.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(10)
            .build(),
      );

      _socket!.on('connect', (_) {
        _log('Socket connected');
        _socket!.emit('subscribe_tracking', {
          'request_id': requestId,
          'token': token,
        });
      });

      _socket!.on('tracking_update', (dynamic data) {
        if (data is Map) {
          unawaited(_onSocketTracking(Map<String, dynamic>.from(data)));
        }
      });

      _socket!.on('tracking_error', (dynamic data) {
        _log('tracking_error: $data');
      });

      _socket!.connect();
    } catch (e) {
      _log('Socket setup error: $e');
    }
  }

  Future<void> _onSocketTracking(Map<String, dynamic> data) async {
    try {
      final snap = TrackingSnapshot.fromJson(data);
      if (!_streamController.isClosed) {
        _streamController.add(snap);
      }
      if (snap.isTerminal) {
        stopTracking();
      }
    } catch (e) {
      _log('tracking_update parse: $e');
    }
  }

  void _disconnectSocket() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
  }

  Future<void> pushDriverLocation({
    required double latitude,
    required double longitude,
    String? activeRequestId,
  }) async {
    try {
      if (AppConfig.useMockApi) {
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

  void dispose() {
    stopTracking();
    _streamController.close();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[TrackingService] $msg');
  }
}
