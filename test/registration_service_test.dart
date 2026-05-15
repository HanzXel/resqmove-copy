import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ResQMove/config/app_config.dart';
import 'package:ResQMove/models/models.dart';
import 'package:ResQMove/services/registration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegistrationService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveFromRemoteUser marks registered and persists fields', () async {
      final ok = await RegistrationService.instance.saveFromRemoteUser(
        const UserModel(
          fullName: 'Maria Santos',
          contactNumber: '09171234567',
          address: 'Cebu City',
          emergencyContact: EmergencyContact(
            name: 'Juan',
            contactNumber: '09170001111',
          ),
        ),
      );
      expect(ok, isTrue);
      expect(await RegistrationService.instance.isRegistered(), isTrue);
      final data = await RegistrationService.instance.loadRegistration();
      expect(data, isNotNull);
      expect(data!.fullName, 'Maria Santos');
      expect(data.mobilePrimary, '09171234567');
      expect(data.address, 'Cebu City');
      expect(data.ecName, 'Juan');
      expect(data.mobileSecondary, '09170001111');
    });
  });

  group('AppConfig', () {
    test('apiBaseUrl is non-empty (override via --dart-define=API_BASE_URL=...)',
        () {
      expect(AppConfig.apiBaseUrl, isNotEmpty);
    });
  });
}
