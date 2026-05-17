// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Tracking Service  (live backend only, no mock)
//  lib/services/tracking_service.dart
//
//  Patient-side tracking: Socket.io push + HTTP polling fallback.
//  Backend: GET /requests/:id/tracking, Socket.io room `track:<requestId>`
//  with event `tracking_update`.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config/app_config.dart';
import '../models/models.dart';
import 'api_client.dart';

// ── Connection state ──────────────────────────────────────────────────────────
enum SocketConnectionState { disconnected, connecting, connected, error }

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
              json['driver_location'] as Map<String, dynamic>)
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
  Timer? _heartbeatTimer;
  socket_io.Socket? _socket;

  final StreamController<TrackingSnapshot> _streamController =
      StreamController<TrackingSnapshot>.broadcast();

  final StreamController<SocketConnectionState> _connController =
      StreamController<SocketConnectionState>.broadcast();

  Stream<TrackingSnapshot> get trackingStream => _streamController.stream;
  Stream<SocketConnectionState> get connectionStateStream =>
      _connController.stream;

  bool get isTracking =>
      (_pollTimer?.isActive ?? false) || (_socket?.connected ?? false);

  String? _currentRequestId;
  int _reconnectDelay = 2;

  // ── Start / Stop ───────────────────────────────────────────────────────────

  void startTracking(String requestId, {int backupPollSeconds = 25}) {
    stopTracking();
    _currentRequestId = requestId;
    _reconnectDelay = 2;

    _log('Tracking started for $requestId');
    unawaited(_fetchAndEmit(requestId));
    unawaited(_connectSocket(requestId));

    _pollTimer = Timer.periodic(
      Duration(seconds: backupPollSeconds),
      (_) => unawaited(_fetchAndEmit(requestId)),
    );
  }

  void stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _disconnectSocket();
    _currentRequestId = null;
    _log('Tracking stopped');
  }

  Future<TrackingSnapshot?> fetchOnce(String requestId) async {
    try {
      return await _fetchSnapshot(requestId);
    } catch (_) {
      return null;
    }
  }

  // ── HTTP fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchAndEmit(String requestId) async {
    try {
      final snapshot = await _fetchSnapshot(requestId);
      _emit(snapshot);
      if (snapshot.isTerminal) {
        _log('Trip terminal — stopping tracker');
        stopTracking();
      }
    } catch (e) {
      _log('HTTP fetch error: $e');
    }
  }

  Future<TrackingSnapshot> _fetchSnapshot(String requestId) async {
    final response = await _client.get('/requests/$requestId/tracking');
    return TrackingSnapshot.fromJson(response.data ?? {});
  }

  void _emit(TrackingSnapshot snap) {
    if (!_streamController.isClosed) _streamController.add(snap);
  }

  // ── Socket.io ─────────────────────────────────────────────────────────────

  String _socketOrigin() {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final port = base.hasPort ? base.port : (base.scheme == 'https' ? 443 : 80);
    return '${base.scheme}://${base.host}:$port';
  }

  Future<void> _connectSocket(String requestId) async {
    _disconnectSocket();
    final token = _client.accessToken;
    if (token == null || token.isEmpty) {
      _log('No access token — socket skipped');
      return;
    }

    _setConnState(SocketConnectionState.connecting);

    try {
      _socket = socket_io.io(
        _socketOrigin(),
        socket_io.OptionBuilder()
            .setTransports(['websocket'])
            .enableReconnection()
            .setReconnectionDelay(_reconnectDelay * 1000)
            .setReconnectionDelayMax(30000)
            .setReconnectionAttempts(20)
            .setTimeout(10000)
            .build(),
      );

      _socket!.on('connect', (_) {
        _log('Socket connected');
        _setConnState(SocketConnectionState.connected);
        _reconnectDelay = 2;
        _socket!.emit('subscribe_tracking', {
          'request_id': requestId,
          'token': token,
        });
        _startHeartbeat(requestId);
      });

      _socket!.on('disconnect', (reason) {
        _log('Socket disconnected: $reason');
        _setConnState(SocketConnectionState.disconnected);
        _heartbeatTimer?.cancel();
        if (reason != 'io client disconnect' && _currentRequestId != null) {
          _scheduleReconnect(requestId);
        }
      });

      _socket!.on('connect_error', (err) {
        _log('Socket connect_error: $err');
        _setConnState(SocketConnectionState.error);
        _heartbeatTimer?.cancel();
        _scheduleReconnect(requestId);
      });

      _socket!.on('tracking_update', (dynamic data) {
        if (data is Map) {
          unawaited(_onSocketTracking(Map<String, dynamic>.from(data)));
        }
      });

      _socket!.on('tracking_error', (dynamic data) => _log('tracking_error: $data'));
      _socket!.on('pong', (_) {});
      _socket!.connect();
    } catch (e) {
      _log('Socket setup error: $e');
      _setConnState(SocketConnectionState.error);
      _scheduleReconnect(requestId);
    }
  }

  void _startHeartbeat(String requestId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_socket?.connected == true) {
        _socket!.emit('ping');
      } else {
        _heartbeatTimer?.cancel();
        if (_currentRequestId != null) _scheduleReconnect(requestId);
      }
    });
  }

  void _scheduleReconnect(String requestId) {
    if (_currentRequestId == null) return;
    final delay = _reconnectDelay;
    _reconnectDelay = (_reconnectDelay * 2).clamp(2, 30);
    Future.delayed(Duration(seconds: delay), () {
      if (_currentRequestId != null) unawaited(_connectSocket(requestId));
    });
  }

  Future<void> _onSocketTracking(Map<String, dynamic> data) async {
    try {
      final snap = TrackingSnapshot.fromJson(data);
      final age = DateTime.now().difference(snap.fetchedAt).inSeconds;
      if (age > 60) return; // stale guard
      _emit(snap);
      if (snap.isTerminal) stopTracking();
    } catch (e) {
      _log('tracking_update parse: $e');
    }
  }

  void _disconnectSocket() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _setConnState(SocketConnectionState.disconnected);
  }

  void _setConnState(SocketConnectionState state) {
    if (!_connController.isClosed) _connController.add(state);
  }

  // ── Driver location push ──────────────────────────────────────────────────

  Future<void> pushDriverLocation({
    required double latitude,
    required double longitude,
    String? activeRequestId,
  }) async {
    try {
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
    _connController.close();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[TrackingService] $msg');
  }
}
