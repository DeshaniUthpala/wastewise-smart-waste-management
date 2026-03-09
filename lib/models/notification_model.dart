import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Notification Model
class NotificationModel {
  final String? id;
  final String userId; // Recipient user ID
  final String title;
  final String message;
  final String type; // 'pickup_scheduled', 'pickup_completed', 'schedule_reminder', 'system', etc.
  final String? relatedEntityId; // ID of related pickup request, schedule, etc.
  final String? relatedEntityType; // 'pickup_request', 'schedule', 'route', etc.
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata; // Additional data

  NotificationModel({
    this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedEntityId,
    this.relatedEntityType,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'uid': userId, // Backward compatibility for legacy payloads
      'title': title,
      'message': message,
      'type': type,
      'relatedEntityId': relatedEntityId,
      'relatedEntityType': relatedEntityType,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'metadata': metadata,
    };
  }

  factory NotificationModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    return NotificationModel(
      id: documentId,
      userId: (map['userId'] ?? map['uid'] ?? '').toString(),
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'system',
      relatedEntityId: map['relatedEntityId'],
      relatedEntityType: map['relatedEntityType'],
      isRead: map['isRead'] ?? false,
      createdAt: _parseFlexibleDateTime(map['createdAt']),
      readAt: _parseFlexibleNullableDateTime(map['readAt']),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    String? relatedEntityId,
    String? relatedEntityType,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
