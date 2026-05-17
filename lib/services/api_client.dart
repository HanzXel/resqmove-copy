// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — API Client
//  lib/services/api_client.dart
//
//  Central HTTP client for all backend communication.
//  Backend: https://resqmove-backend.onrender.com/api/v1
//
//  Tokens are persisted with SharedPreferences.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'app_messenger.dart';

/// Default timeout for all HTTP requests.
const Duration _timeout = Duration(seconds: 15);

// ── Token Storage (memory + SharedPreferences) ────────────────────────────────

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

  static const _prefsAccess = 'resqmove_access_token';
  static const _prefsRefresh = 'resqmove_refresh_token';
  static const _prefsSessionType = 'resqmove_session_type';

  /// Call from `main()` before `runApp` so authenticated requests work on cold start.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final access = prefs.getString(_prefsAccess);
      final refresh = prefs.getString(_prefsRefresh);
      if (access != null && access.isNotEmpty) {
        _TokenStore.setTokens(access: access, refresh: refresh);
      }
    } catch (_) {}
  }

  // ── Auth token helpers ─────────────────────────────────────────────────────

  void setTokens({required String access, String? refresh}) {
    _TokenStore.setTokens(access: access, refresh: refresh);
    unawaited(_persistTokensToDisk());
  }

  Future<void> clearTokens() async {
    _TokenStore.clear();
    unawaited(_clearTokensFromDisk());
    unawaited(_clearSessionTypeFromDisk());
  }

  // ── Session type helpers (driver vs patient) ───────────────────────────────

  Future<void> saveSessionType(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsSessionType, type);
    } catch (_) {}
  }

  Future<String?> getSessionType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsSessionType);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSessionTypeFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsSessionType);
    } catch (_) {}
  }

  Future<void> _persistTokensToDisk() async {
    final access = _TokenStore.accessToken;
    if (access == null || access.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsAccess, access);
      final refresh = _TokenStore.refreshToken;
      if (refresh != null && refresh.isNotEmpty) {
        await prefs.setString(_prefsRefresh, refresh);
      } else {
        await prefs.remove(_prefsRefresh);
      }
    } catch (_) {}
  }

  Future<void> _clearTokensFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsAccess);
      await prefs.remove(_prefsRefresh);
    } catch (_) {}
  }

  bool get isAuthenticated => _TokenStore.accessToken != null;

  /// JWT for Socket.io `subscribe_tracking` (same value as the Bearer header).
  String? get accessToken => _TokenStore.accessToken;

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
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, null);
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? _timeout);
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
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, null);
    try {
      final response = await http
          .put(
            uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? _timeout);
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
    final base = Uri.parse('${AppConfig.apiBaseUrl}$fullPath');
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
      AppMessenger.showErrorThrottled(
        'No internet connection. Check your network and try again.',
      );
      return const ApiException(
        message: 'No internet connection. Please check your network.',
      );
    }
    if (error is TimeoutException) {
      AppMessenger.showErrorThrottled(
        'The server took too long to respond.',
      );
      return const ApiException(message: 'Request timed out. Please try again.');
    }
    if (error is HttpException) {
      return ApiException(message: 'Network error: ${error.message}');
    }
    return ApiException(message: 'Unexpected error: $error');
  }
}
