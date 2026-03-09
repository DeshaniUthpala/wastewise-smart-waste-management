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

/// Pickup Request Model
class PickupRequestModel {
  final String? id;
  final String citizenId;
  final String? driverId;
  final LocationModel location;
  final String wasteType;
  final String? wasteCategory;
  final double? estimatedWeight; // in kg
  final String status; // 'pending', 'assigned', 'in_progress', 'completed', 'cancelled'
  final DateTime requestedDate;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final String? specialInstructions;
  final List<String>? imageUrls;
  final String? collectionFeedback;
  final double? rating;

  PickupRequestModel({
    this.id,
    required this.citizenId,
    this.driverId,
    required this.location,
    required this.wasteType,
    this.wasteCategory,
    this.estimatedWeight,
    this.status = 'pending',
    required this.requestedDate,
    this.scheduledDate,
    this.completedDate,
    this.specialInstructions,
    this.imageUrls,
    this.collectionFeedback,
    this.rating,
  });

  Map<String, dynamic> toMap() {
    return {
      'citizenId': citizenId,
      'driverId': driverId,
      'location': location.toMap(),
      'wasteType': wasteType,
      'wasteCategory': wasteCategory,
      'estimatedWeight': estimatedWeight,
      'status': status,
      'requestedDate': Timestamp.fromDate(requestedDate),
      'scheduledDate':
          scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'completedDate':
          completedDate != null ? Timestamp.fromDate(completedDate!) : null,
      'specialInstructions': specialInstructions,
      'imageUrls': imageUrls,
      'collectionFeedback': collectionFeedback,
      'rating': rating,
    };
  }

  factory PickupRequestModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return PickupRequestModel(
      id: documentId,
      citizenId: (map['citizenId'] ?? map['userId'] ?? map['uid'] ?? '').toString(),
      driverId: map['driverId'],
      location: LocationModel.fromMap(map['location'] ?? {}),
      wasteType: map['wasteType'] ?? '',
      wasteCategory: map['wasteCategory'],
      estimatedWeight: map['estimatedWeight']?.toDouble(),
      status: map['status'] ?? 'pending',
      requestedDate: _parseFlexibleDateTime(
        map['requestedDate'] ?? map['createdAt'],
      ),
      scheduledDate: _parseFlexibleNullableDateTime(map['scheduledDate']),
      completedDate: _parseFlexibleNullableDateTime(map['completedDate']),
      specialInstructions: map['specialInstructions'],
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : null,
      collectionFeedback: map['collectionFeedback'],
      rating: map['rating']?.toDouble(),
    );
  }

  PickupRequestModel copyWith({
    String? id,
    String? citizenId,
    String? driverId,
    LocationModel? location,
    String? wasteType,
    String? wasteCategory,
    double? estimatedWeight,
    String? status,
    DateTime? requestedDate,
    DateTime? scheduledDate,
    DateTime? completedDate,
    String? specialInstructions,
    List<String>? imageUrls,
    String? collectionFeedback,
    double? rating,
  }) {
    return PickupRequestModel(
      id: id ?? this.id,
      citizenId: citizenId ?? this.citizenId,
      driverId: driverId ?? this.driverId,
      location: location ?? this.location,
      wasteType: wasteType ?? this.wasteType,
      wasteCategory: wasteCategory ?? this.wasteCategory,
      estimatedWeight: estimatedWeight ?? this.estimatedWeight,
      status: status ?? this.status,
      requestedDate: requestedDate ?? this.requestedDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      imageUrls: imageUrls ?? this.imageUrls,
      collectionFeedback: collectionFeedback ?? this.collectionFeedback,
      rating: rating ?? this.rating,
    );
  }
}
