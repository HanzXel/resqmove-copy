import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'registration_service.dart';

/// Keeps the server-side patient session aligned with local registration.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  /// Logs in with Mobile No. 1 and pushes profile fields to the API.
  Future<void> syncPatientFromRegistration() async {
    try {
      final reg = await RegistrationService.instance.loadRegistration();
      if (reg == null || reg.mobilePrimary.trim().isEmpty) return;

      final login = await AuthService.instance.loginAsPatient(
        contactNumber: reg.mobilePrimary.trim(),
      );
      if (!login.success) {
        if (kDebugMode) {
          debugPrint(
              '[SessionService] Patient login failed: ${login.errorMessage}');
        }
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
        debugPrint(
            '[SessionService] Profile update failed: ${profile.errorMessage}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[SessionService] syncPatientFromRegistration: $e\n$st');
      }
    }
  }
}
