// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Auth Service
//  lib/services/auth_service.dart
//
//  Handles login, logout, and session state for both:
//    • Patients  (phone-number based, no password needed on patient side)
//    • Drivers   (username + password, as seen in driver_login_screen.dart)
//
//  HOW MOCK MODE WORKS:
//  - _mockMode = true  → simulates login success, returns fake tokens
//  - _mockMode = false → hits real backend endpoints via ApiClient
//
//  ENDPOINTS YOUR CLASSMATE NEEDS TO IMPLEMENT:
//    POST /auth/patient/login   body: { contact_number }
//    POST /auth/driver/login    body: { username, password, unit_id? }
//    POST /auth/logout          header: Authorization Bearer <token>
//    POST /auth/refresh         body: { refresh_token }
//
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
  //  Patient-side login uses contact number only (no password).
  //  Adjust body fields to match your classmate's API contract.

  Future<AuthResult> loginAsPatient({
    required String contactNumber,
  }) async {
    try {
      if (_mockMode) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        _currentUser = UserModel(
          id: 'mock-user-001',
          fullName: '',
          contactNumber: contactNumber,
        );
        _isDriverSession = false;
        _client.setTokens(access: 'mock-access-token', refresh: 'mock-refresh-token');
        _log('Patient login OK (mock) contact=$contactNumber');
        return AuthResult.success(user: _currentUser);
      }

      final response = await _client.post(
        '/auth/patient/login',
        body: {'contact_number': contactNumber},
        auth: false,
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
  //  Matches the fields in driver_login_screen.dart:
  //  username/driver-ID, password, and optional unit_id.

  Future<AuthResult> loginAsDriver({
    required String username,
    required String password,
    String? unitId,
  }) async {
    try {
      if (_mockMode) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        _currentDriver = DriverModel(
          id: 'mock-driver-001',
          fullName: '',
          driverId: username,
          contactNumber: '',
          unitId: unitId,
          status: DriverStatus.offline,
        );
        _isDriverSession = true;
        _client.setTokens(access: 'mock-driver-token', refresh: 'mock-driver-refresh');
        _log('Driver login OK (mock) username=$username');
        return AuthResult.success(driver: _currentDriver);
      }

      final response = await _client.post(
        '/auth/driver/login',
        body: {
          'username': username,
          'password': password,
          if (unitId != null && unitId.isNotEmpty) 'unit_id': unitId,
        },
        auth: false,
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

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      if (!_mockMode && isLoggedIn) {
        await _client.post('/auth/logout');
      }
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
  //  Call this if a request returns 401 Unauthorized.
  //  Your UI layer can call this and retry the failed request.

  Future<bool> refreshToken() async {
    if (_mockMode) return true;
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

  void updateCachedUser(UserModel user) {
    _currentUser = user;
  }

  void updateCachedDriver(DriverModel driver) {
    _currentDriver = driver;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _handleTokensFromResponse(Map<String, dynamic>? data) {
    if (data == null) return;
    final access = data['access_token']?.toString() ??
        data['token']?.toString() ??
        data['access']?.toString();
    final refresh = data['refresh_token']?.toString() ??
        data['refresh']?.toString();
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

// ── Toggle mock mode (mirrors ApiClient setting) ──────────────────────────────
//  Keep this in sync with api_client.dart's _mockMode constant.
const bool _mockMode = true;
