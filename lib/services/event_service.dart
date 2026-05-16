// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Event Standby & BLS Service
//  lib/services/event_service.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'api_client.dart';

class EventBookingResult {
  final bool success;
  final String? id;
  final String? errorMessage;

  const EventBookingResult._({
    required this.success,
    this.id,
    this.errorMessage,
  });

  factory EventBookingResult.success(String id) =>
      EventBookingResult._(success: true, id: id);

  factory EventBookingResult.failure(String message) =>
      EventBookingResult._(success: false, errorMessage: message);
}

class EventService {
  EventService._();
  static final EventService instance = EventService._();

  final ApiClient _client = ApiClient.instance;

  // ── Submit event medical standby booking ───────────────────────────────────
  Future<EventBookingResult> submitStandby({
    required String eventName,
    required String location,
    required String eventDate,
    String? expectedAttendees,
    String? contactPerson,
  }) async {
    try {
      final response = await _client.post('/events/standby', body: {
        'event_name': eventName,
        'location': location,
        'event_date': eventDate,
        if (expectedAttendees != null && expectedAttendees.isNotEmpty)
          'expected_attendees': expectedAttendees,
        if (contactPerson != null && contactPerson.isNotEmpty)
          'contact_person': contactPerson,
      });

      final id = response.data?['booking']?['id']?.toString() ?? 'N/A';
      _log('Event standby booked: $id');
      return EventBookingResult.success(id);
    } on ApiException catch (e) {
      _log('Event standby failed: ${e.message}');
      return EventBookingResult.failure(e.message);
    } catch (e) {
      _log('Event standby error: $e');
      return EventBookingResult.failure('Failed to submit booking. Please try again.');
    }
  }

  // ── Submit BLS request ─────────────────────────────────────────────────────
  Future<EventBookingResult> submitBls({
    required double latitude,
    required double longitude,
    String? address,
    String? notes,
  }) async {
    try {
      final response = await _client.post('/events/bls', body: {
        'pickup_location': {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null && address.isNotEmpty) 'address': address,
        },
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final id = response.data?['request']?['id']?.toString() ?? 'N/A';
      _log('BLS request submitted: $id');
      return EventBookingResult.success(id);
    } on ApiException catch (e) {
      _log('BLS failed: ${e.message}');
      return EventBookingResult.failure(e.message);
    } catch (e) {
      _log('BLS error: $e');
      return EventBookingResult.failure('Failed to submit BLS request. Please try again.');
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[EventService] $msg');
  }
}
