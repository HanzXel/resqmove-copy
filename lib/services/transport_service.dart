import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_client.dart';

class TransportBookingResult {
  final bool success;
  final String? id;
  final String? errorMessage;

  const TransportBookingResult._({
    required this.success,
    this.id,
    this.errorMessage,
  });

  factory TransportBookingResult.ok(String id) =>
      TransportBookingResult._(success: true, id: id);

  factory TransportBookingResult.fail(String message) =>
      TransportBookingResult._(success: false, errorMessage: message);
}

/// Non-emergency scheduled transport (patient app).
class TransportService {
  TransportService._();
  static final TransportService instance = TransportService._();

  final ApiClient _client = ApiClient.instance;

  Future<TransportBookingResult> submitBooking({
    required String patientName,
    required String pickupAddress,
    required String destinationHospital,
    required String contactNumber,
    required DateTime scheduledAt,
  }) async {
    try {
      if (AppConfig.useMockApi) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return TransportBookingResult.ok('mock-transport-id');
      }

      final response = await _client.post(
        '/transport',
        body: {
          'patient_name': patientName,
          'pickup_address': pickupAddress,
          'destination_hospital': destinationHospital,
          'contact_number': contactNumber,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        },
      );

      final booking =
          response.data?['booking'] as Map<String, dynamic>? ?? response.data!;
      final id = booking['id']?.toString();
      if (id == null || id.isEmpty) {
        return TransportBookingResult.fail('Invalid server response.');
      }
      return TransportBookingResult.ok(id);
    } on ApiException catch (e) {
      return TransportBookingResult.fail(e.message);
    } catch (e) {
      if (kDebugMode) debugPrint('[TransportService] $e');
      return TransportBookingResult.fail('Could not submit booking.');
    }
  }
}
