import '../models/models.dart';

/// Normalizes an [AmbulanceRequestModel] for driver UI screens that expect
/// `emergencyType`, `location`, and nested `pickup_location`.
Map<String, dynamic> driverRequestMapForUi(AmbulanceRequestModel r) {
  final addr = r.pickupLocation.address?.trim() ?? '';
  final fallbackLoc = addr.isNotEmpty
      ? addr
      : '${r.pickupLocation.latitude.toStringAsFixed(5)}, ${r.pickupLocation.longitude.toStringAsFixed(5)}';
  return {
    if (r.id != null) 'id': r.id,
    'emergency_type': r.emergencyType.apiValue,
    'emergencyType': r.emergencyType.label,
    'location': fallbackLoc,
    'pickup_location': r.pickupLocation.toJson(),
    'status': r.status.label,
    'contact': '',
  };
}
