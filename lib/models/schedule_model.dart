import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

DateTime _parseFlexibleDateTime(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final asInt = int.tryParse(value);
    if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}

DateTime? _parseFlexibleNullableDateTime(dynamic value) {
  if (value == null) return null;
  return _parseFlexibleDateTime(value);
}

/// Schedule Model for regular waste collection schedules
class ScheduleModel {
  final String? id;
  final String area; // Area/zone name
  final String wasteType; // e.g., 'Organic', 'Recyclable', 'Hazardous'
  final List<String> daysOfWeek; // ['Monday', 'Wednesday', 'Friday']
  final String collectionTime; // e.g., '08:00 AM'
  final String? driverId;
  final String? routeId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUpdated;
  final LocationModel? location;
  final String? description;
  
  // New fields for data isolation
  final bool isCommon; // If true, visible to everyone. If false, checked against citizenId
  final String? citizenId; // The specific user this schedule belongs to (if not common)
  final String? pickupRequestId; // Optional link to a specific request

  ScheduleModel({
    this.id,
    required this.area,
    required this.wasteType,
    required this.daysOfWeek,
    required this.collectionTime,
    this.driverId,
    this.routeId,
    this.isActive = true,
    required this.createdAt,
    this.lastUpdated,
    this.location,
    this.description,
    this.isCommon = true, // Default to true for backward compatibility
    this.citizenId,
    this.pickupRequestId,
  });

  Map<String, dynamic> toMap() {
    return {
      'area': area,
      'wasteType': wasteType,
      'daysOfWeek': daysOfWeek,
      'collectionTime': collectionTime,
      'driverId': driverId,
      'routeId': routeId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated':
          lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      'location': location?.toMap(),
      'description': description,
      'isCommon': isCommon,
      'citizenId': citizenId,
      'pickupRequestId': pickupRequestId,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ScheduleModel(
      id: documentId,
      area: map['area'] ?? '',
      wasteType: map['wasteType'] ?? '',
      daysOfWeek: List<String>.from(map['daysOfWeek'] ?? []),
      collectionTime: map['collectionTime'] ?? '',
      driverId: map['driverId'],
      routeId: map['routeId'],
      isActive: map['isActive'] ?? true,
      createdAt: _parseFlexibleDateTime(map['createdAt']),
      lastUpdated: _parseFlexibleNullableDateTime(map['lastUpdated']),
      location: map['location'] != null
          ? LocationModel.fromMap(map['location'])
          : null,
      description: map['description'],
      isCommon: map['isCommon'] ?? true,
      citizenId: map['citizenId'],
      pickupRequestId: map['pickupRequestId'],
    );
  }

  ScheduleModel copyWith({
    String? id,
    String? area,
    String? wasteType,
    List<String>? daysOfWeek,
    String? collectionTime,
    String? driverId,
    String? routeId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastUpdated,
    LocationModel? location,
    String? description,
    bool? isCommon,
    String? citizenId,
    String? pickupRequestId,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      area: area ?? this.area,
      wasteType: wasteType ?? this.wasteType,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      collectionTime: collectionTime ?? this.collectionTime,
      driverId: driverId ?? this.driverId,
      routeId: routeId ?? this.routeId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      location: location ?? this.location,
      description: description ?? this.description,
      isCommon: isCommon ?? this.isCommon,
      citizenId: citizenId ?? this.citizenId,
      pickupRequestId: pickupRequestId ?? this.pickupRequestId,
    );
  }
}
