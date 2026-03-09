import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleModel {
  final String? id;
  final String vehicleNumber;
  final String vehicleType; // Truck, Van, etc.
  final double capacity; // in kg
  final bool isActive;
  final String? assignedDriverId;
  final DateTime? lastMaintenance;

  VehicleModel({
    this.id,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.capacity,
    this.isActive = true,
    this.assignedDriverId,
    this.lastMaintenance,
  });

  Map<String, dynamic> toMap() {
    return {
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'capacity': capacity,
      'isActive': isActive,
      'assignedDriverId': assignedDriverId,
      'lastMaintenance': lastMaintenance != null
          ? Timestamp.fromDate(lastMaintenance!)
          : null,
    };
  }

  factory VehicleModel.fromMap(Map<String, dynamic> map, String documentId) {
    return VehicleModel(
      id: documentId,
      vehicleNumber: map['vehicleNumber'] ?? '',
      vehicleType: map['vehicleType'] ?? 'Truck',
      capacity: (map['capacity'] ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? true,
      assignedDriverId: map['assignedDriverId'],
      lastMaintenance: (map['lastMaintenance'] as Timestamp?)?.toDate(),
    );
  }
}
