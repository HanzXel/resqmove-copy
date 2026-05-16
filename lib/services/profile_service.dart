// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Profile Service
//  lib/services/profile_service.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'registration_service.dart';
import '../models/models.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final ApiClient _client = ApiClient.instance;

  // ── Get patient profile ────────────────────────────────────────────────────

  Future<ProfileResult<UserModel>> getPatientProfile() async {
    try {
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 400));

        // [FIX 2] If no cached user, hydrate from local registration data
        final cached = AuthService.instance.currentUser;
        if (cached != null && cached.fullName.isNotEmpty) {
          return ProfileResult.success(cached);
        }

        final reg = await RegistrationService.instance.loadRegistration();
        if (reg != null && !reg.isEmpty) {
          final user = UserModel(
            id: 'local-user',
            fullName: reg.fullName,
            contactNumber: reg.mobilePrimary,
            address: reg.address.isNotEmpty ? reg.address : null,
            emergencyContact: (reg.ecName.isNotEmpty || reg.mobileSecondary.isNotEmpty)
                ? EmergencyContact(
                    name: reg.ecName,
                    contactNumber: reg.mobileSecondary,
                  )
                : null,
          );
          AuthService.instance.updateCachedUser(user);
          return ProfileResult.success(user);
        }

        return ProfileResult.success(UserModel.empty());
      }

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
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        AuthService.instance.updateCachedUser(user);
        _log('Patient profile updated (mock)');
        return ProfileResult.success(user);
      }

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
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final cached = AuthService.instance.currentDriver;
        if (cached != null) return ProfileResult.success(cached);
        return ProfileResult.success(DriverModel.empty());
      }

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
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        AuthService.instance.updateCachedDriver(driver);
        _log('Driver profile updated (mock)');
        return ProfileResult.success(driver);
      }

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
