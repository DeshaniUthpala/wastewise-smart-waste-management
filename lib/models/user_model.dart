import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDateTime(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    final asInt = int.tryParse(value);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  return _parseDateTime(value);
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<String> _parseStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

/// Base User Model
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String role; // 'admin', 'citizen', 'driver'
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.profileImageUrl,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'isActive': isActive,
    };
  }

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: map['role'] ?? 'citizen',
      profileImageUrl: map['profileImageUrl'],
      createdAt: _parseDateTime(map['createdAt']),
      lastLogin: _parseNullableDateTime(map['lastLogin']),
      isActive: map['isActive'] ?? true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Citizen-specific Model
class CitizenModel extends UserModel {
  final String? address;
  final LocationModel? location;
  final int rewardPoints;
  final List<String> wastePreferences; // Types of waste they manage

  CitizenModel({
    required super.uid,
    required super.name,
    required super.email,
    super.phone,
    super.profileImageUrl,
    required super.createdAt,
    super.lastLogin,
    super.isActive,
    this.address,
    this.location,
    this.rewardPoints = 0,
    this.wastePreferences = const [],
  }) : super(role: 'citizen');

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'address': address,
      'location': location?.toMap(),
      'rewardPoints': rewardPoints,
      'wastePreferences': wastePreferences,
    });
    return map;
  }

  factory CitizenModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CitizenModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      profileImageUrl: map['profileImageUrl'],
      createdAt: _parseDateTime(map['createdAt']),
      lastLogin: _parseNullableDateTime(map['lastLogin']),
      isActive: map['isActive'] ?? true,
      address: map['address'],
      location: map['location'] != null
          ? LocationModel.fromMap(map['location'])
          : null,
      rewardPoints: _parseInt(map['rewardPoints']),
      wastePreferences: _parseStringList(map['wastePreferences']),
    );
  }
}

/// Driver-specific Model
class DriverModel extends UserModel {
  final String? vehicleId; // Reference to VehicleModel
  final String? vehicleNumber;
  final String? vehicleType;
  final String? licenseNumber;
  final bool isAvailable;
  final String? currentRouteId;
  final LocationModel? currentLocation;
  final double? rating;
  final int completedPickups;

  DriverModel({
    required super.uid,
    required super.name,
    required super.email,
    super.phone,
    super.profileImageUrl,
    required super.createdAt,
    super.lastLogin,
    super.isActive,
    this.vehicleId,
    this.vehicleNumber,
    this.vehicleType,
    this.licenseNumber,
    this.isAvailable = true,
    this.currentRouteId,
    this.currentLocation,
    this.rating,
    this.completedPickups = 0,
  }) : super(role: 'driver');

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'vehicleId': vehicleId,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'licenseNumber': licenseNumber,
      'isAvailable': isAvailable,
      'currentRouteId': currentRouteId,
      'currentLocation': currentLocation?.toMap(),
      'rating': rating,
      'completedPickups': completedPickups,
    });
    return map;
  }

  factory DriverModel.fromMap(Map<String, dynamic> map, String documentId) {
    return DriverModel(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      profileImageUrl: map['profileImageUrl'],
      createdAt: _parseDateTime(map['createdAt']),
      lastLogin: _parseNullableDateTime(map['lastLogin']),
      isActive: map['isActive'] ?? true,
      vehicleId: map['vehicleId'],
      vehicleNumber: map['vehicleNumber'],
      vehicleType: map['vehicleType'],
      licenseNumber: map['licenseNumber'],
      isAvailable: map['isAvailable'] ?? true,
      currentRouteId: map['currentRouteId'],
      currentLocation: map['currentLocation'] != null
          ? LocationModel.fromMap(map['currentLocation'])
          : null,
      rating: _parseNullableDouble(map['rating']),
      completedPickups: _parseInt(map['completedPickups']),
    );
  }
}

/// Location Model
class LocationModel {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? postalCode;

  LocationModel({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.postalCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'postalCode': postalCode,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'],
      city: map['city'],
      postalCode: map['postalCode'],
    );
  }
}
