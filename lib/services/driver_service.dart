// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Driver Service  (live backend only, no mock)
//  lib/services/driver_service.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_service.dart';
import '../models/models.dart';

class DriverService {
  DriverService._();
  static final DriverService instance = DriverService._();

  final ApiClient _client = ApiClient.instance;

  // ── Toggle driver availability ─────────────────────────────────────────────

  Future<DriverResult> setStatus(DriverStatus status) async {
    try {
      await _client.patch('/driver/status', body: {'status': status.label});
      final updated = AuthService.instance.currentDriver?.copyWith(status: status);
      if (updated != null) AuthService.instance.updateCachedDriver(updated);
      _log('Status set to ${status.label}');
      return DriverResult.success();
    } on ApiException catch (e) {
      return DriverResult.failure(e.message);
    } catch (e) {
      return DriverResult.failure('Failed to update status.');
    }
  }

  // ── Fetch pending incoming requests ────────────────────────────────────────

  Future<RequestListResult> getIncomingRequests() async {
    try {
      final response = await _client.get('/driver/requests');
      final list = response.data?['requests'] as List<dynamic>? ?? [];
      final requests = list
          .whereType<Map<String, dynamic>>()
          .map(AmbulanceRequestModel.fromJson)
          .toList();
      return RequestListResult._(success: true, requests: requests);
    } on ApiException catch (e) {
      return RequestListResult._(
          success: false, requests: const [], errorMessage: e.message);
    } catch (e) {
      return RequestListResult._(
          success: false,
          requests: const [],
          errorMessage: 'Failed to load requests.');
    }
  }

  // ── Get driver's currently active trip ─────────────────────────────────────

  Future<ActiveTripResult> getActiveTrip() async {
    try {
      final response = await _client.get('/driver/active-trip');
      final data = response.data;

      if (data == null || data['request'] == null) {
        return const ActiveTripResult._(success: true, request: null);
      }

      final request = AmbulanceRequestModel.fromJson(
        data['request'] as Map<String, dynamic>,
      );
      return ActiveTripResult._(success: true, request: request);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return const ActiveTripResult._(success: true, request: null);
      }
      return ActiveTripResult._(
          success: false, request: null, errorMessage: e.message);
    } catch (e) {
      return ActiveTripResult._(
          success: false,
          request: null,
          errorMessage: 'Failed to fetch active trip.');
    }
  }

  // ── Accept a trip request ──────────────────────────────────────────────────

  Future<DriverResult> acceptRequest(String requestId) async {
    try {
      await _client.post('/driver/requests/$requestId/accept');
      _log('Request $requestId accepted');
      return DriverResult.success();
    } on ApiException catch (e) {
      return DriverResult.failure(e.message);
    } catch (e) {
      return DriverResult.failure('Failed to accept request.');
    }
  }

  // ── Decline a trip request ─────────────────────────────────────────────────

  Future<DriverResult> declineRequest(String requestId) async {
    try {
      await _client.post('/driver/requests/$requestId/decline');
      _log('Request $requestId declined');
      return DriverResult.success();
    } on ApiException catch (e) {
      return DriverResult.failure(e.message);
    } catch (e) {
      return DriverResult.failure('Failed to decline request.');
    }
  }

  // ── Fetch trip history ─────────────────────────────────────────────────────

  Future<RequestListResult> getTripHistory() async {
    try {
      final response = await _client.get(
        '/driver/trips',
        queryParams: {'status': 'completed,cancelled'},
      );
      final list = response.data?['trips'] as List<dynamic>? ?? [];
      final trips = list
          .whereType<Map<String, dynamic>>()
          .map(AmbulanceRequestModel.fromJson)
          .toList();
      return RequestListResult._(success: true, requests: trips);
    } on ApiException catch (e) {
      return RequestListResult._(
          success: false, requests: const [], errorMessage: e.message);
    } catch (e) {
      return RequestListResult._(
          success: false,
          requests: const [],
          errorMessage: 'Failed to load trip history.');
    }
  }

  // ── Complete an active trip ────────────────────────────────────────────────

  Future<DriverResult> completeTrip(String requestId) async {
    try {
      await _client.post('/driver/trips/$requestId/complete');
      _log('Trip $requestId completed');
      return DriverResult.success();
    } on ApiException catch (e) {
      return DriverResult.failure(e.message);
    } catch (e) {
      return DriverResult.failure('Failed to complete trip.');
    }
  }

  // ── Fetch today's driver stats ─────────────────────────────────────────────

  Future<DriverStats> getStats() async {
    try {
      final response = await _client.get('/driver/stats');
      return DriverStats.fromJson(response.data ?? {});
    } catch (_) {
      return DriverStats.empty();
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[DriverService] $msg');
  }
}

// ── Result types ──────────────────────────────────────────────────────────────

class DriverResult {
  final bool success;
  final String? errorMessage;

  const DriverResult._({required this.success, this.errorMessage});

  factory DriverResult.success() => const DriverResult._(success: true);
  factory DriverResult.failure(String message) =>
      DriverResult._(success: false, errorMessage: message);
}

class RequestListResult {
  final bool success;
  final List<AmbulanceRequestModel> requests;
  final String? errorMessage;

  const RequestListResult._({
    required this.success,
    required this.requests,
    this.errorMessage,
  });
}

class ActiveTripResult {
  final bool success;
  final AmbulanceRequestModel? request;
  final String? errorMessage;

  const ActiveTripResult._({
    required this.success,
    this.request,
    this.errorMessage,
  });
}
