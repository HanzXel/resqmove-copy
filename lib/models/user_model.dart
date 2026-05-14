// ─────────────────────────────────────────────────────────────────────────────
//  ResQMove — User Model
//  lib/models/user_model.dart
//
//  Represents a patient/civilian user of the app.
//  fromJson() maps directly to your database response fields.
//  toJson() is used when sending data to the backend.
// ─────────────────────────────────────────────────────────────────────────────

class UserModel {
  final String? id;
  final String fullName;
  final String contactNumber;
  final String? address;
  final String? preferredHospital;
  final EmergencyContact? emergencyContact;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    this.id,
    required this.fullName,
    required this.contactNumber,
    this.address,
    this.preferredHospital,
    this.emergencyContact,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a blank/empty user (used before login or profile setup)
  factory UserModel.empty() => const UserModel(
        fullName: '',
        contactNumber: '',
      );

  /// Map from JSON response (database → app)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      address: json['address']?.toString(),
      preferredHospital: json['preferred_hospital']?.toString(),
      emergencyContact: json['emergency_contact'] != null
          ? EmergencyContact.fromJson(
              json['emergency_contact'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Convert to JSON (app → database)
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'full_name': fullName,
        'contact_number': contactNumber,
        if (address != null) 'address': address,
        if (preferredHospital != null) 'preferred_hospital': preferredHospital,
        if (emergencyContact != null)
          'emergency_contact': emergencyContact!.toJson(),
      };

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? fullName,
    String? contactNumber,
    String? address,
    String? preferredHospital,
    EmergencyContact? emergencyContact,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      preferredHospital: preferredHospital ?? this.preferredHospital,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool get isEmpty => fullName.isEmpty && contactNumber.isEmpty;
}

// ── Emergency Contact ─────────────────────────────────────────────────────────

class EmergencyContact {
  final String name;
  final String contactNumber;

  const EmergencyContact({
    required this.name,
    required this.contactNumber,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact_number': contactNumber,
      };
}
