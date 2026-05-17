import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'auth_service.dart';
import 'api_client.dart';
import 'profile_service.dart';
import 'registration_service.dart';

/// Keeps the server-side patient session aligned with local registration.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  /// Logs in with Mobile No. 1 and pushes profile fields to the API.
  /// [FIX] Added retry on failure so cold-start Render delays don't break auth.
  Future<void> syncPatientFromRegistration({int retries = 2}) async {
    try {
      final reg = await RegistrationService.instance.loadRegistration();
      if (reg == null || reg.mobilePrimary.trim().isEmpty) return;

      // If already authenticated (token in memory), skip re-login
      if (ApiClient.instance.isAuthenticated) {
        _log('Session already active — skipping re-login.');
        return;
      }

      AuthResult login = await AuthService.instance.loginAsPatient(
        contactNumber: reg.mobilePrimary.trim(),
      );

      // Retry once on failure (handles Render cold-start delays)
      if (!login.success && retries > 0) {
        _log('Retrying patient login (${retries} left)...');
        await Future.delayed(const Duration(seconds: 4));
        login = await AuthService.instance.loginAsPatient(
          contactNumber: reg.mobilePrimary.trim(),
        );
      }

      if (!login.success) {
        _log('Patient login failed after retries: ${login.errorMessage}');
        return;
      }

      final user = UserModel(
        id: AuthService.instance.currentUser?.id,
        fullName: reg.fullName.trim(),
        contactNumber: reg.mobilePrimary.trim(),
        address: reg.address.trim().isEmpty ? null : reg.address.trim(),
        emergencyContact: (reg.ecName.trim().isNotEmpty ||
                reg.mobileSecondary.trim().isNotEmpty)
            ? EmergencyContact(
                name: reg.ecName.trim(),
                contactNumber: reg.mobileSecondary.trim(),
              )
            : null,
      );

      final profile = await ProfileService.instance.updatePatientProfile(user);
      if (!profile.success && kDebugMode) {
        _log('Profile update failed: ${profile.errorMessage}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        _log('syncPatientFromRegistration error: $e\n$st');
      }
    }
  }

  /// Ensures the patient has a valid auth token before making API calls.
  /// Call this before submitting any request if the auth state is uncertain.
  Future<bool> ensurePatientAuthenticated() async {
    if (ApiClient.instance.isAuthenticated) return true;

    try {
      final reg = await RegistrationService.instance.loadRegistration();
      if (reg == null || reg.mobilePrimary.trim().isEmpty) return false;

      final login = await AuthService.instance.loginAsPatient(
        contactNumber: reg.mobilePrimary.trim(),
      );
      return login.success;
    } catch (_) {
      return false;
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[SessionService] $msg');
  }
}
