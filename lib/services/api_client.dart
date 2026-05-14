// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — API Client
//  lib/services/api_client.dart
//
//  Central HTTP client for all backend communication.
//
//  HOW TO CONNECT TO THE DATABASE (for your classmate):
//  1. Change [baseUrl] to your actual backend server URL.
//     e.g. 'https://api.resqmove.com/api/v1'
//         or 'http://192.168.1.10:8000/api'  (local dev)
//  2. All services (AuthService, RequestService, etc.) already use
//     this client — no other changes needed across the codebase.
//
//  CURRENT STATE: Runs in mock mode (no real server needed yet).
//  Set [mockMode = false] once the backend is ready.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Configuration ─────────────────────────────────────────────────────────────

/// Base URL of the backend API.
/// Your classmate (DB side) only needs to change this one constant.
const String _baseUrl = 'http://YOUR_SERVER_IP:8000/api/v1';

/// Toggle mock mode ON during development (no server needed).
/// Set to false once the real backend is live.
const bool _mockMode = true;

/// Default timeout for all HTTP requests.
const Duration _timeout = Duration(seconds: 15);

// ── Token Storage (in-memory; swap for shared_preferences in production) ──────

class _TokenStore {
  static String? _accessToken;
  static String? _refreshToken;

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;

  static void setTokens({required String access, String? refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  static void clear() {
    _accessToken = null;
    _refreshToken = null;
  }
}

// ── API Exception ─────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data;

  const ApiException({this.statusCode, required this.message, this.data});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ── API Response Wrapper ──────────────────────────────────────────────────────

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });
}

// ── API Client ────────────────────────────────────────────────────────────────

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // ── Auth token helpers ─────────────────────────────────────────────────────

  void setTokens({required String access, String? refresh}) {
    _TokenStore.setTokens(access: access, refresh: refresh);
  }

  void clearTokens() => _TokenStore.clear();

  bool get isAuthenticated => _TokenStore.accessToken != null;

  // ── Request headers ────────────────────────────────────────────────────────

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (auth && _TokenStore.accessToken != null) {
      headers[HttpHeaders.authorizationHeader] =
          'Bearer ${_TokenStore.accessToken}';
    }
    return headers;
  }

  // ── HTTP helpers ───────────────────────────────────────────────────────────

  /// GET request
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? queryParams,
    bool auth = true,
  }) async {
    if (_mockMode) {
      return _mockResponse(path, method: 'GET');
    }

    final uri = _buildUri(path, queryParams);
    try {
      final response = await http
          .get(uri, headers: _headers(auth: auth))
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    if (_mockMode) {
      return _mockResponse(path, method: 'POST', body: body);
    }

    final uri = _buildUri(path, null);
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<ApiResponse<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    if (_mockMode) {
      return _mockResponse(path, method: 'PUT', body: body);
    }

    final uri = _buildUri(path, null);
    try {
      final response = await http
          .put(
            uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<ApiResponse<Map<String, dynamic>>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    if (_mockMode) {
      return _mockResponse(path, method: 'PATCH', body: body);
    }

    final uri = _buildUri(path, null);
    try {
      final response = await http
          .patch(
            uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    bool auth = true,
  }) async {
    if (_mockMode) {
      return _mockResponse(path, method: 'DELETE');
    }

    final uri = _buildUri(path, null);
    try {
      final response = await http
          .delete(uri, headers: _headers(auth: auth))
          .timeout(_timeout);
      return _parseResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── URI builder ────────────────────────────────────────────────────────────

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final fullPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$_baseUrl$fullPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      return base.replace(queryParameters: queryParams);
    }
    return base;
  }

  // ── Response parser ────────────────────────────────────────────────────────

  ApiResponse<Map<String, dynamic>> _parseResponse(http.Response response) {
    late Map<String, dynamic> body;

    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = {'message': response.body};
    }

    final isSuccess =
        response.statusCode >= 200 && response.statusCode < 300;

    if (!isSuccess) {
      throw ApiException(
        statusCode: response.statusCode,
        message: body['message']?.toString() ??
            body['detail']?.toString() ??
            'Request failed',
        data: body,
      );
    }

    return ApiResponse(
      success: true,
      data: body,
      statusCode: response.statusCode,
      message: body['message']?.toString(),
    );
  }

  // ── Error handler ──────────────────────────────────────────────────────────

  ApiException _handleError(dynamic error) {
    if (error is ApiException) return error;
    if (error is SocketException) {
      return const ApiException(
        message: 'No internet connection. Please check your network.',
      );
    }
    if (error is HttpException) {
      return ApiException(message: 'Network error: ${error.message}');
    }
    return ApiException(message: 'Unexpected error: $error');
  }

  // ── Mock mode ──────────────────────────────────────────────────────────────
  //  Returns empty success responses so UI works without a server.
  //  Your classmate's backend will replace this automatically
  //  once _mockMode is set to false.

  Future<ApiResponse<Map<String, dynamic>>> _mockResponse(
    String path, {
    required String method,
    Map<String, dynamic>? body,
  }) async {
    // Simulate network latency
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (kDebugMode) {
      debugPrint('[ApiClient MOCK] $method $path body=$body');
    }

    // Return a generic success shell — services will layer real data on top
    return const ApiResponse(
      success: true,
      data: {'message': 'mock_ok'},
      statusCode: 200,
    );
  }
}
