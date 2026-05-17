// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Auth Service  (live backend only, no mock)
//  lib/services/auth_service.dart
//
//  ENDPOINTS:
//    POST /auth/patient/login   body: { contact_number }
//    POST /auth/driver/register body: { driver_id, password, full_name, ... }
//    POST /auth/driver/login    body: { username, password, unit_id? }
//    POST /auth/logout          header: Authorization Bearer <token>
//    POST /auth/refresh         body: { refresh_token }
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/models.dart';

// ── Auth Result ───────────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final String? errorMessage;
  final UserModel? user;
  final DriverModel? driver;

  const AuthResult._({
    required this.success,
    this.errorMessage,
    this.user,
    this.driver,
  });

  factory AuthResult.success({UserModel? user, DriverModel? driver}) =>
      AuthResult._(success: true, user: user, driver: driver);

  factory AuthResult.failure(String message) =>
      AuthResult._(success: false, errorMessage: message);
}

// ── Auth Service ──────────────────────────────────────────────────────────────

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const Duration _authNetworkTimeout = Duration(seconds: 45);

  final ApiClient _client = ApiClient.instance;

  // ── Session state ──────────────────────────────────────────────────────────

  UserModel? _currentUser;
  DriverModel? _currentDriver;
  bool _isDriverSession = false;

  UserModel? get currentUser => _currentUser;
  DriverModel? get currentDriver => _currentDriver;
  bool get isLoggedIn => _client.isAuthenticated;
  bool get isDriverSession => _isDriverSession;
  bool get isPatientSession => isLoggedIn && !_isDriverSession;

  // ── Patient Login ──────────────────────────────────────────────────────────

  Future<AuthResult> loginAsPatient({required String contactNumber}) async {
    try {
      final response = await _client.post(
        '/auth/patient/login',
        body: {'contact_number': contactNumber},
        auth: false,
        timeout: _authNetworkTimeout,
      );

      _handleTokensFromResponse(response.data);
      _currentUser = _parseUser(response.data);
      _isDriverSession = false;

      _log('Patient login OK id=${_currentUser?.id}');
      return AuthResult.success(user: _currentUser);
    } on ApiException catch (e) {
      _log('Patient login FAILED: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      _log('Patient login ERROR: $e');
      return AuthResult.failure('Login failed. Please try again.');
    }
  }

  // ── Driver Login ───────────────────────────────────────────────────────────

  Future<AuthResult> loginAsDriver({
    required String username,
    required String password,
    String? unitId,
  }) async {
    try {
      final response = await _client.post(
        '/auth/driver/login',
        body: {
          'username': username,
          'password': password,
          if (unitId != null && unitId.isNotEmpty) 'unit_id': unitId,
        },
        auth: false,
        timeout: _authNetworkTimeout,
      );

      _handleTokensFromResponse(response.data);
      _currentDriver = _parseDriver(response.data);
      _isDriverSession = true;

      _log('Driver login OK id=${_currentDriver?.id}');
      return AuthResult.success(driver: _currentDriver);
    } on ApiException catch (e) {
      _log('Driver login FAILED: ${e.message}');
      return AuthResult.failure(e.message);
    } catch (e) {
      _log('Driver login ERROR: $e');
      return AuthResult.failure('Login failed. Please try again.');
    }
  }

  // ── Driver Register ────────────────────────────────────────────────────────

  Future<AuthResult> registerDriver({
    required String driverId,
    required String password,
    required String fullName,
    String contactNumber = '',
    String? unitId,
    String? hospitalName,
    String? unitType,
  }) async {
    try {
      await _client.post(
        '/auth/driver/register',
        auth: false,
        timeout: _authNetworkTimeout,
        body: {
          'driver_id': driverId.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'contact_number': contactNumber.trim(),
          if (unitId != null && unitId.trim().isNotEmpty) 'unit_id': unitId.trim(),
          if (hospitalName != null && hospitalName.trim().isNotEmpty)
            'hospital_name': hospitalName.trim(),
          if (unitType != null && unitType.trim().isNotEmpty)
            'unit_type': unitType.trim(),
        },
      );
      return AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Registration failed. Please try again.');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      if (isLoggedIn) await _client.post('/auth/logout');
    } catch (_) {
      // Always clear local state even if server call fails
    } finally {
      _currentUser = null;
      _currentDriver = null;
      _isDriverSession = false;
      _client.clearTokens();
      _log('Session cleared');
    }
  }

  // ── Token Refresh ──────────────────────────────────────────────────────────

  Future<bool> refreshToken() async {
    try {
      final response = await _client.post(
        '/auth/refresh',
        body: {'refresh_token': 'stored-refresh-token'},
        auth: false,
      );
      _handleTokensFromResponse(response.data);
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  // ── Update cached user/driver after profile save ───────────────────────────

  void updateCachedUser(UserModel user) => _currentUser = user;
  void updateCachedDriver(DriverModel driver) => _currentDriver = driver;

  // ── Private helpers ────────────────────────────────────────────────────────

  void _handleTokensFromResponse(Map<String, dynamic>? data) {
    if (data == null) return;
    final access = data['access_token']?.toString() ??
        data['token']?.toString() ??
        data['access']?.toString();
    final refresh =
        data['refresh_token']?.toString() ?? data['refresh']?.toString();
    if (access != null) {
      _client.setTokens(access: access, refresh: refresh);
    }
  }

  UserModel? _parseUser(Map<String, dynamic>? data) {
    if (data == null) return null;
    final userData = data['user'] as Map<String, dynamic>? ?? data;
    return UserModel.fromJson(userData);
  }

  DriverModel? _parseDriver(Map<String, dynamic>? data) {
    if (data == null) return null;
    final driverData = data['driver'] as Map<String, dynamic>? ?? data;
    return DriverModel.fromJson(driverData);
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[AuthService] $msg');
  }
}
