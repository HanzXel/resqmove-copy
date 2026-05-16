// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Request Service
//  lib/services/request_service.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'mock_state.dart';
import '../models/models.dart';

class RequestService {
  RequestService._();
  static final RequestService instance = RequestService._();

  final ApiClient _client = ApiClient.instance;

  // ── Submit a new ambulance request ─────────────────────────────────────────

  Future<RequestResult> submitRequest({
    required String emergencyTypeLabel,
    required double latitude,
    required double longitude,
    String? address,
    String? notes,
  }) async {
    try {
      final emergencyType = EmergencyTypeX.fromString(emergencyTypeLabel);
      final location = RequestLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        final mockRequest = AmbulanceRequestModel(
          id: 'mock-req-${DateTime.now().millisecondsSinceEpoch}',
          emergencyType: emergencyType,
          status: RequestStatus.pending,
          pickupLocation: location,
          notes: notes,
          requestedAt: DateTime.now(),
        );
        // [FIX] Store in shared mock state so driver side can see it
        MockState.instance.submitRequest(mockRequest);
        _log('Request submitted (mock): ${mockRequest.id}');
        return RequestResult.success(mockRequest);
      }

      final response = await _client.post(
        '/requests',
        body: {
          'emergency_type': emergencyType.apiValue,
          'pickup_location': location.toJson(),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

      final request = AmbulanceRequestModel.fromJson(
        response.data?['request'] as Map<String, dynamic>? ?? response.data!,
      );
      _log('Request submitted: ${request.id}');
      return RequestResult.success(request);
    } on ApiException catch (e) {
      _log('Submit failed: ${e.message}');
      return RequestResult.failure(e.message);
    } catch (e) {
      _log('Submit error: $e');
      return RequestResult.failure('Failed to submit request. Please try again.');
    }
  }

  // ── Get a single request by ID ─────────────────────────────────────────────

  Future<RequestResult> getRequest(String requestId) async {
    try {
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final r = MockState.instance.activeRequest;
        if (r != null && r.id == requestId) return RequestResult.success(r);
        return RequestResult.success(_mockPendingRequest(requestId));
      }

      final response = await _client.get('/requests/$requestId');
      final request = AmbulanceRequestModel.fromJson(
        response.data?['request'] as Map<String, dynamic>? ?? response.data!,
      );
      return RequestResult.success(request);
    } on ApiException catch (e) {
      return RequestResult.failure(e.message);
    } catch (e) {
      return RequestResult.failure('Failed to fetch request.');
    }
  }

  // ── Get the currently active request for the logged-in patient ─────────────

  Future<RequestResult> getActiveRequest() async {
    try {
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        // [FIX] Return from shared mock state so tracking screen works
        final r = MockState.instance.activeRequest;
        if (r != null && r.isActive) {
          return RequestResult.success(r);
        }
        return const RequestResult._(success: true, request: null);
      }

      final response = await _client.get('/requests/active');
      final data = response.data;

      if (data == null || data['request'] == null) {
        return const RequestResult._(success: true, request: null);
      }

      final request = AmbulanceRequestModel.fromJson(
        data['request'] as Map<String, dynamic>,
      );
      return RequestResult.success(request);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return const RequestResult._(success: true, request: null);
      }
      return RequestResult.failure(e.message);
    } catch (e) {
      return RequestResult.failure('Failed to fetch active request.');
    }
  }

  // ── Cancel an active request ───────────────────────────────────────────────

  Future<RequestResult> cancelRequest(String requestId) async {
    try {
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        MockState.instance.clear();
        _log('Request cancelled (mock): $requestId');
        return const RequestResult._(success: true, request: null);
      }

      await _client.patch('/requests/$requestId/cancel');
      _log('Request cancelled: $requestId');
      return const RequestResult._(success: true, request: null);
    } on ApiException catch (e) {
      return RequestResult.failure(e.message);
    } catch (e) {
      return RequestResult.failure('Failed to cancel request.');
    }
  }

  // ── Get request history for the patient ───────────────────────────────────

  Future<HistoryResult> getRequestHistory() async {
    try {
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return const HistoryResult._(success: true, requests: []);
      }

      final response = await _client.get('/requests/history');
      final list = response.data?['requests'] as List<dynamic>? ?? [];
      final requests = list
          .whereType<Map<String, dynamic>>()
          .map(AmbulanceRequestModel.fromJson)
          .toList();
      return HistoryResult._(success: true, requests: requests);
    } on ApiException catch (e) {
      return HistoryResult._(success: false, requests: const [], errorMessage: e.message);
    } catch (e) {
      return HistoryResult._(success: false, requests: const [], errorMessage: 'Failed to load history.');
    }
  }

  // ── App-wide stats ─────────────────────────────────────────────────────────

  Future<AppStatsModel> getAppStats() async {
    try {
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return AppStatsModel.empty();
      }

      final response = await _client.get('/stats', auth: false);
      return AppStatsModel.fromJson(response.data ?? {});
    } catch (_) {
      return AppStatsModel.empty();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  AmbulanceRequestModel _mockPendingRequest(String id) {
    return AmbulanceRequestModel(
      id: id,
      emergencyType: EmergencyType.other,
      status: RequestStatus.pending,
      pickupLocation: const RequestLocation(
        latitude: 10.3220,
        longitude: 123.8920,
        address: 'Cebu City, PH',
      ),
      requestedAt: DateTime.now(),
    );
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[RequestService] $msg');
  }
}

// ── Result types ──────────────────────────────────────────────────────────────

class RequestResult {
  final bool success;
  final AmbulanceRequestModel? request;
  final String? errorMessage;

  const RequestResult._({
    required this.success,
    this.request,
    this.errorMessage,
  });

  factory RequestResult.success(AmbulanceRequestModel request) =>
      RequestResult._(success: true, request: request);

  factory RequestResult.failure(String message) =>
      RequestResult._(success: false, errorMessage: message);
}

class HistoryResult {
  final bool success;
  final List<AmbulanceRequestModel> requests;
  final String? errorMessage;

  const HistoryResult._({
    required this.success,
    required this.requests,
    this.errorMessage,
  });
}
