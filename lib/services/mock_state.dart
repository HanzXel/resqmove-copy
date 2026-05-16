// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Mock State Bridge
//  lib/services/mock_state.dart
//
//  In-memory singleton that simulates backend state in mock mode.
//  Allows the driver side and patient side to share state within the same app
//  session so acceptance/tracking works end-to-end without a real server.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import '../models/models.dart';

class MockState {
  MockState._();
  static final MockState instance = MockState._();

  // ── Active request (set by patient when they submit) ──────────────────────
  AmbulanceRequestModel? activeRequest;

  // ── Driver location (updated by driver navigation / active trip) ──────────
  double driverLat = 10.3220;
  double driverLng = 10.3220;

  // ── Stream so the patient tracking screen reacts in real time ─────────────
  final StreamController<AmbulanceRequestModel?> _requestController =
      StreamController<AmbulanceRequestModel?>.broadcast();

  Stream<AmbulanceRequestModel?> get requestStream => _requestController.stream;

  /// Called by request_service when patient submits
  void submitRequest(AmbulanceRequestModel req) {
    activeRequest = req;
    _requestController.add(req);
  }

  /// Called by driver_service when driver accepts
  void acceptRequest(String requestId) {
    final r = activeRequest;
    if (r == null || r.id != requestId) return;
    activeRequest = r.copyWith(
      status: RequestStatus.accepted,
      acceptedAt: DateTime.now(),
    );
    _requestController.add(activeRequest);
  }

  /// Called by driver when trip progresses / completes
  void updateStatus(String requestId, RequestStatus status) {
    final r = activeRequest;
    if (r == null || r.id != requestId) return;
    activeRequest = r.copyWith(status: status);
    _requestController.add(activeRequest);
  }

  /// Called by driver navigation to update live location
  void updateDriverLocation(double lat, double lng) {
    driverLat = lat;
    driverLng = lng;
  }

  /// Clear everything (e.g. trip completed / cancelled)
  void clear() {
    activeRequest = null;
    driverLat = 10.3220;
    driverLng = 10.3220;
    _requestController.add(null);
  }
}
