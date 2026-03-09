import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// Route Model for driver routes
class RouteModel {
  final String? id;
  final String name;
  final String? driverId;
  final List<LocationModel> waypoints;
  final List<String> pickupRequestIds; // Associated pickup requests
  final String status; // 'planned', 'in_progress', 'completed'
  final DateTime? startTime;
  final DateTime? endTime;
  final double? totalDistance; // in kilometers
  final int? estimatedDuration; // in minutes
  final DateTime createdAt;

  RouteModel({
    this.id,
    required this.name,
    this.driverId,
    this.waypoints = const [],
    this.pickupRequestIds = const [],
    this.status = 'planned',
    this.startTime,
    this.endTime,
    this.totalDistance,
    this.estimatedDuration,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'driverId': driverId,
      'waypoints': waypoints.map((w) => w.toMap()).toList(),
      'pickupRequestIds': pickupRequestIds,
      'status': status,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'totalDistance': totalDistance,
      'estimatedDuration': estimatedDuration,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RouteModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RouteModel(
      id: documentId,
      name: map['name'] ?? '',
      driverId: map['driverId'],
      waypoints: (map['waypoints'] as List<dynamic>?)
              ?.map((w) => LocationModel.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      pickupRequestIds: List<String>.from(map['pickupRequestIds'] ?? []),
      status: map['status'] ?? 'planned',
      startTime: (map['startTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      totalDistance: map['totalDistance']?.toDouble(),
      estimatedDuration: map['estimatedDuration'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Waste Type Model
class WasteTypeModel {
  final String? id;
  final String name;
  final String category; // 'Organic', 'Recyclable', 'Hazardous', 'Electronic', 'General'
  final String? description;
  final String? iconUrl;
  final String? color; // Hex color code
  final bool isRecyclable;
  final List<String> disposalInstructions;

  WasteTypeModel({
    this.id,
    required this.name,
    required this.category,
    this.description,
    this.iconUrl,
    this.color,
    this.isRecyclable = false,
    this.disposalInstructions = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'iconUrl': iconUrl,
      'color': color,
      'isRecyclable': isRecyclable,
      'disposalInstructions': disposalInstructions,
    };
  }

  factory WasteTypeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return WasteTypeModel(
      id: documentId,
      name: map['name'] ?? '',
      category: map['category'] ?? 'General',
      description: map['description'],
      iconUrl: map['iconUrl'],
      color: map['color'],
      isRecyclable: map['isRecyclable'] ?? false,
      disposalInstructions:
          List<String>.from(map['disposalInstructions'] ?? []),
    );
  }
}
