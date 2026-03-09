import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String? id;
  final String requestId; // Link to PickupRequest
  final String driverId; // Link to Driver
  final DateTime assignedDate;
  final String status; // 'assigned', 'accepted', 'completed', 'failed'
  final DateTime? completionDate;
  final String? notes;

  TaskModel({
    this.id,
    required this.requestId,
    required this.driverId,
    required this.assignedDate,
    this.status = 'assigned',
    this.completionDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'driverId': driverId,
      'assignedDate': Timestamp.fromDate(assignedDate),
      'status': status,
      'completionDate': completionDate != null
          ? Timestamp.fromDate(completionDate!)
          : null,
      'notes': notes,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskModel(
      id: documentId,
      requestId: map['requestId'] ?? '',
      driverId: map['driverId'] ?? '',
      assignedDate: (map['assignedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'assigned',
      completionDate: (map['completionDate'] as Timestamp?)?.toDate(),
      notes: map['notes'],
    );
  }
}
