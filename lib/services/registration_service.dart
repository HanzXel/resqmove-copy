// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Registration Service
//  lib/services/registration_service.dart
//
//  Stores basic biographic data locally (SharedPreferences) so the app
//  remembers the user's profile without requiring a server login.
//
//  Fields stored:
//    • full_name
//    • address
//    • mobile_primary    (Mobile No. 1 — phone owner)
//    • mobile_secondary  (Mobile No. 2 — emergency contact person)
//    • ec_name           (name of secondary contact)
//    • barangay
//    • is_registered     (bool flag — skip sign-up on next launch)
//
//  To use SharedPreferences, add to pubspec.yaml:
//    shared_preferences: ^2.2.3
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class RegistrationData {
  final String fullName;
  final String barangay;
  final String address;
  final String mobilePrimary;
  final String mobileSecondary;
  final String ecName;

  const RegistrationData({
    required this.fullName,
    required this.barangay,
    required this.address,
    required this.mobilePrimary,
    required this.mobileSecondary,
    required this.ecName,
  });

  bool get isEmpty => fullName.isEmpty && mobilePrimary.isEmpty;
}

class RegistrationService {
  RegistrationService._();
  static final RegistrationService instance = RegistrationService._();

  // ─── Keys ──────────────────────────────────────────────────────────────────
  static const _kRegistered        = 'resqmove_is_registered';
  static const _kFullName          = 'resqmove_full_name';
  static const _kBarangay          = 'resqmove_barangay';
  static const _kAddress           = 'resqmove_address';
  static const _kMobilePrimary     = 'resqmove_mobile_primary';
  static const _kMobileSecondary   = 'resqmove_mobile_secondary';
  static const _kEcName            = 'resqmove_ec_name';

  // ─── Check whether user has already registered ────────────────────────────
  Future<bool> isRegistered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kRegistered) ?? false;
    } catch (e) {
      _log('isRegistered error: $e');
      return false;
    }
  }

  // ─── Save registration data ────────────────────────────────────────────────
  /// After a successful server login, mirror the patient profile locally so
  /// [isRegistered] is true and the main shell can load without re-filling the form.
  Future<bool> saveFromRemoteUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ec = user.emergencyContact;
      await prefs.setBool(_kRegistered, true);
      await prefs.setString(_kFullName, user.fullName);
      await prefs.setString(_kBarangay, '');
      await prefs.setString(_kAddress, user.address ?? '');
      await prefs.setString(_kMobilePrimary, user.contactNumber);
      await prefs.setString(_kMobileSecondary, ec?.contactNumber ?? '');
      await prefs.setString(_kEcName, ec?.name ?? '');
      _log('Local registration hydrated from server user id=${user.id}');
      return true;
    } catch (e) {
      _log('saveFromRemoteUser error: $e');
      return false;
    }
  }

  Future<bool> saveRegistration(RegistrationData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRegistered,       true);
      await prefs.setString(_kFullName,        data.fullName);
      await prefs.setString(_kBarangay,        data.barangay);
      await prefs.setString(_kAddress,         data.address);
      await prefs.setString(_kMobilePrimary,   data.mobilePrimary);
      await prefs.setString(_kMobileSecondary, data.mobileSecondary);
      await prefs.setString(_kEcName,          data.ecName);
      _log('Registration saved for ${data.fullName}');
      return true;
    } catch (e) {
      _log('saveRegistration error: $e');
      return false;
    }
  }

  // ─── Load saved registration data ─────────────────────────────────────────
  Future<RegistrationData?> loadRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_kRegistered) ?? false)) return null;
      return RegistrationData(
        fullName:        prefs.getString(_kFullName)        ?? '',
        barangay:        prefs.getString(_kBarangay)        ?? '',
        address:         prefs.getString(_kAddress)         ?? '',
        mobilePrimary:   prefs.getString(_kMobilePrimary)   ?? '',
        mobileSecondary: prefs.getString(_kMobileSecondary) ?? '',
        ecName:          prefs.getString(_kEcName)          ?? '',
      );
    } catch (e) {
      _log('loadRegistration error: $e');
      return null;
    }
  }

  // ─── Clear registration (for testing / logout) ────────────────────────────
  Future<void> clearRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRegistered);
      await prefs.remove(_kFullName);
      await prefs.remove(_kBarangay);
      await prefs.remove(_kAddress);
      await prefs.remove(_kMobilePrimary);
      await prefs.remove(_kMobileSecondary);
      await prefs.remove(_kEcName);
    } catch (e) {
      _log('clearRegistration error: $e');
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[RegistrationService] $msg');
  }
}
