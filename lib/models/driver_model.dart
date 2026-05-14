// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — Driver Model
//  lib/models/driver_model.dart
//
//  Represents a ResQMove ambulance driver.
//  Mirrors the driver_profile_screen fields exactly.
// ─────────────────────────────────────────────────────────────────────────────

/// Availability status of the driver
enum DriverStatus { available, busy, offline }

extension DriverStatusX on DriverStatus {
  String get label {
    switch (this) {
      case DriverStatus.available:
        return 'available';
      case DriverStatus.busy:
        return 'busy';
      case DriverStatus.offline:
        return 'offline';
    }
  }

  static DriverStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'available':
        return DriverStatus.available;
      case 'busy':
        return DriverStatus.busy;
      default:
        return DriverStatus.offline;
    }
  }
}

// ── Driver Model ──────────────────────────────────────────────────────────────

class DriverModel {
  final String? id;
  final String fullName;
  final String driverId;       // e.g. "DRV-001"
  final String contactNumber;
  final String? unitId;        // e.g. "RESQ-101"
  final String? hospitalName;  // e.g. "Chong Hua Hospital"
  final String? unitType;      // e.g. "ALS" / "BLS"
  final DriverStatus status;
  final DriverLocation? currentLocation;
  final DriverStats? stats;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DriverModel({
    this.id,
    required this.fullName,
    required this.driverId,
    required this.contactNumber,
    this.unitId,
    this.hospitalName,
    this.unitType,
    this.status = DriverStatus.offline,
    this.currentLocation,
    this.stats,
    this.createdAt,
    this.updatedAt,
  });

  factory DriverModel.empty() => const DriverModel(
        fullName: '',
        driverId: '',
        contactNumber: '',
      );

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      unitId: json['unit_id']?.toString(),
      hospitalName: json['hospital_name']?.toString(),
      unitType: json['unit_type']?.toString(),
      status: DriverStatusX.fromString(json['status']?.toString()),
      currentLocation: json['current_location'] != null
          ? DriverLocation.fromJson(
              json['current_location'] as Map<String, dynamic>)
          : null,
      stats: json['stats'] != null
          ? DriverStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'full_name': fullName,
        'driver_id': driverId,
        'contact_number': contactNumber,
        if (unitId != null) 'unit_id': unitId,
        if (hospitalName != null) 'hospital_name': hospitalName,
        if (unitType != null) 'unit_type': unitType,
        'status': status.label,
      };

  DriverModel copyWith({
    String? id,
    String? fullName,
    String? driverId,
    String? contactNumber,
    String? unitId,
    String? hospitalName,
    String? unitType,
    DriverStatus? status,
    DriverLocation? currentLocation,
    DriverStats? stats,
  }) {
    return DriverModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      driverId: driverId ?? this.driverId,
      contactNumber: contactNumber ?? this.contactNumber,
      unitId: unitId ?? this.unitId,
      hospitalName: hospitalName ?? this.hospitalName,
      unitType: unitType ?? this.unitType,
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      stats: stats ?? this.stats,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isEmpty => fullName.isEmpty && driverId.isEmpty;
  bool get isAvailable => status == DriverStatus.available;
}

// ── Driver Location ───────────────────────────────────────────────────────────

class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  const DriverLocation({
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp?.toIso8601String(),
      };
}

// ── Driver Stats (today's summary) ───────────────────────────────────────────

class DriverStats {
  final int tripsCompleted;
  final int pendingRequests;
  final String avgResponseTime; // e.g. "6 min"

  const DriverStats({
    this.tripsCompleted = 0,
    this.pendingRequests = 0,
    this.avgResponseTime = '--',
  });

  factory DriverStats.empty() => const DriverStats();

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    return DriverStats(
      tripsCompleted: (json['trips_completed'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pending_requests'] as num?)?.toInt() ?? 0,
      avgResponseTime: json['avg_response_time']?.toString() ?? '--',
    );
  }

  Map<String, dynamic> toJson() => {
        'trips_completed': tripsCompleted,
        'pending_requests': pendingRequests,
        'avg_response_time': avgResponseTime,
      };
}
