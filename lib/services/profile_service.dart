// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Profile Service  (live backend only, no mock)
//  lib/services/profile_service.dart
//
//  ENDPOINTS:
//    GET /profile/patient  → returns patient profile
//    PUT /profile/patient  → updates patient profile
//    GET /profile/driver   → returns driver profile
//    PUT /profile/driver   → updates driver profile
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_service.dart';
import '../models/models.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final ApiClient _client = ApiClient.instance;

  // ── Get patient profile ────────────────────────────────────────────────────

  Future<ProfileResult<UserModel>> getPatientProfile() async {
    try {
      final response = await _client.get('/profile/patient');
      final user = UserModel.fromJson(
        response.data?['user'] as Map<String, dynamic>? ?? response.data!,
      );
      AuthService.instance.updateCachedUser(user);
      return ProfileResult.success(user);
    } on ApiException catch (e) {
      return ProfileResult.failure(e.message);
    } catch (e) {
      return ProfileResult.failure('Failed to load profile.');
    }
  }

  // ── Update patient profile ─────────────────────────────────────────────────

  Future<ProfileResult<UserModel>> updatePatientProfile(UserModel user) async {
    try {
      final response = await _client.put(
        '/profile/patient',
        body: user.toJson(),
        timeout: const Duration(seconds: 45),
      );
      final updated = UserModel.fromJson(
        response.data?['user'] as Map<String, dynamic>? ?? response.data!,
      );
      AuthService.instance.updateCachedUser(updated);
      _log('Patient profile updated: ${updated.id}');
      return ProfileResult.success(updated);
    } on ApiException catch (e) {
      return ProfileResult.failure(e.message);
    } catch (e) {
      return ProfileResult.failure('Failed to update profile.');
    }
  }

  // ── Get driver profile ─────────────────────────────────────────────────────

  Future<ProfileResult<DriverModel>> getDriverProfile() async {
    try {
      final response = await _client.get('/profile/driver');
      final driver = DriverModel.fromJson(
        response.data?['driver'] as Map<String, dynamic>? ?? response.data!,
      );
      AuthService.instance.updateCachedDriver(driver);
      return ProfileResult.success(driver);
    } on ApiException catch (e) {
      return ProfileResult.failure(e.message);
    } catch (e) {
      return ProfileResult.failure('Failed to load driver profile.');
    }
  }

  // ── Update driver profile ──────────────────────────────────────────────────

  Future<ProfileResult<DriverModel>> updateDriverProfile(DriverModel driver) async {
    try {
      final response = await _client.put(
        '/profile/driver',
        body: driver.toJson(),
      );
      final updated = DriverModel.fromJson(
        response.data?['driver'] as Map<String, dynamic>? ?? response.data!,
      );
      AuthService.instance.updateCachedDriver(updated);
      _log('Driver profile updated: ${updated.id}');
      return ProfileResult.success(updated);
    } on ApiException catch (e) {
      return ProfileResult.failure(e.message);
    } catch (e) {
      return ProfileResult.failure('Failed to update driver profile.');
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ProfileService] $msg');
  }
}

// ── Result type ───────────────────────────────────────────────────────────────

class ProfileResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  const ProfileResult._({required this.success, this.data, this.errorMessage});

  factory ProfileResult.success(T data) =>
      ProfileResult._(success: true, data: data);

  factory ProfileResult.failure(String message) =>
      ProfileResult._(success: false, errorMessage: message);
}
