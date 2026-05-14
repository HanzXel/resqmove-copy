// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Ambulance Request Model
//  lib/models/ambulance_request_model.dart
//
//  Represents a single emergency ambulance request made by a patient.
//  Maps to the home_screen emergency type list and booking_screen fields.
// ─────────────────────────────────────────────────────────────────────────────

/// All valid emergency types — matches the list in home_screen.dart
enum EmergencyType {
  cardiacArrest,
  stroke,
  severeTrama,
  roadAccident,
  difficultyBreathing,
  unconscious,
  seizure,
  severeBleeeding,
  childbirth,
  other,
}

extension EmergencyTypeX on EmergencyType {
  String get label {
    switch (this) {
      case EmergencyType.cardiacArrest:
        return 'Cardiac Arrest';
      case EmergencyType.stroke:
        return 'Stroke';
      case EmergencyType.severeTrama:
        return 'Severe Trauma / Injury';
      case EmergencyType.roadAccident:
        return 'Road Traffic Accident';
      case EmergencyType.difficultyBreathing:
        return 'Difficulty Breathing';
      case EmergencyType.unconscious:
        return 'Unconscious / Unresponsive';
      case EmergencyType.seizure:
        return 'Seizure';
      case EmergencyType.severeBleeeding:
        return 'Severe Bleeding';
      case EmergencyType.childbirth:
        return 'Childbirth / Obstetric Emergency';
      case EmergencyType.other:
        return 'Other Emergency';
    }
  }

  String get apiValue => label.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_');

  static EmergencyType fromString(String? value) {
    for (final type in EmergencyType.values) {
      if (type.label == value || type.apiValue == value) return type;
    }
    return EmergencyType.other;
  }
}

// ── Request Status ────────────────────────────────────────────────────────────

enum RequestStatus {
  pending,      // Waiting for a driver to accept
  accepted,     // Driver accepted, en route to patient
  inProgress,   // Ambulance on scene / transporting
  completed,    // Trip finished
  cancelled,    // Cancelled by patient or system
  declined,     // No driver accepted
}

extension RequestStatusX on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending:      return 'pending';
      case RequestStatus.accepted:     return 'accepted';
      case RequestStatus.inProgress:   return 'in_progress';
      case RequestStatus.completed:    return 'completed';
      case RequestStatus.cancelled:    return 'cancelled';
      case RequestStatus.declined:     return 'declined';
    }
  }

  static RequestStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':      return RequestStatus.pending;
      case 'accepted':     return RequestStatus.accepted;
      case 'in_progress':  return RequestStatus.inProgress;
      case 'completed':    return RequestStatus.completed;
      case 'cancelled':    return RequestStatus.cancelled;
      case 'declined':     return RequestStatus.declined;
      default:             return RequestStatus.pending;
    }
  }
}

// ── Ambulance Request Model ───────────────────────────────────────────────────

class AmbulanceRequestModel {
  final String? id;
  final String? userId;
  final EmergencyType emergencyType;
  final RequestStatus status;
  final RequestLocation pickupLocation;
  final String? assignedDriverId;
  final String? assignedUnitId;
  final String? destinationHospital;
  final String? notes;
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  const AmbulanceRequestModel({
    this.id,
    this.userId,
    required this.emergencyType,
    this.status = RequestStatus.pending,
    required this.pickupLocation,
    this.assignedDriverId,
    this.assignedUnitId,
    this.destinationHospital,
    this.notes,
    this.requestedAt,
    this.acceptedAt,
    this.completedAt,
  });

  factory AmbulanceRequestModel.fromJson(Map<String, dynamic> json) {
    return AmbulanceRequestModel(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString(),
      emergencyType:
          EmergencyTypeX.fromString(json['emergency_type']?.toString()),
      status: RequestStatusX.fromString(json['status']?.toString()),
      pickupLocation: RequestLocation.fromJson(
          json['pickup_location'] as Map<String, dynamic>),
      assignedDriverId: json['assigned_driver_id']?.toString(),
      assignedUnitId: json['assigned_unit_id']?.toString(),
      destinationHospital: json['destination_hospital']?.toString(),
      notes: json['notes']?.toString(),
      requestedAt: json['requested_at'] != null
          ? DateTime.tryParse(json['requested_at'].toString())
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (userId != null) 'user_id': userId,
        'emergency_type': emergencyType.apiValue,
        'status': status.label,
        'pickup_location': pickupLocation.toJson(),
        if (assignedDriverId != null) 'assigned_driver_id': assignedDriverId,
        if (assignedUnitId != null) 'assigned_unit_id': assignedUnitId,
        if (destinationHospital != null)
          'destination_hospital': destinationHospital,
        if (notes != null) 'notes': notes,
      };

  AmbulanceRequestModel copyWith({
    String? id,
    RequestStatus? status,
    String? assignedDriverId,
    String? assignedUnitId,
    String? destinationHospital,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return AmbulanceRequestModel(
      id: id ?? this.id,
      userId: userId,
      emergencyType: emergencyType,
      status: status ?? this.status,
      pickupLocation: pickupLocation,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedUnitId: assignedUnitId ?? this.assignedUnitId,
      destinationHospital: destinationHospital ?? this.destinationHospital,
      notes: notes,
      requestedAt: requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get isActive =>
      status == RequestStatus.pending ||
      status == RequestStatus.accepted ||
      status == RequestStatus.inProgress;
}

// ── Request Location ──────────────────────────────────────────────────────────

class RequestLocation {
  final double latitude;
  final double longitude;
  final String? address;    // Human-readable address (optional)

  const RequestLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory RequestLocation.fromJson(Map<String, dynamic> json) {
    return RequestLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
      };
}
