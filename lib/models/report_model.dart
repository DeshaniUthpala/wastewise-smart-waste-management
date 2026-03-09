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

/// Report Model for issues and complaints
class ReportModel {
  final String? id;
  final String reporterId; // User who reported
  final String title;
  final String description;
  final String type; // 'missed_pickup', 'illegal_dumping', 'bin_issue', 'other'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final LocationModel? location;
  final List<String>? imageUrls;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? assignedTo; // Admin/Driver ID
  final String? resolutionNotes;

  ReportModel({
    this.id,
    required this.reporterId,
    required this.title,
    required this.description,
    required this.type,
    this.priority = 'medium',
    this.status = 'open',
    this.location,
    this.imageUrls,
    required this.createdAt,
    this.resolvedAt,
    this.assignedTo,
    this.resolutionNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'uid': reporterId, // Legacy compatibility for old payloads
      'title': title,
      'description': description,
      'type': type,
      'priority': priority,
      'status': status,
      'location': location?.toMap(),
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'assignedTo': assignedTo,
      'resolutionNotes': resolutionNotes,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReportModel(
      id: documentId,
      reporterId: (map['reporterId'] ?? map['uid'] ?? '').toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'other',
      priority: map['priority'] ?? 'medium',
      status: map['status'] ?? 'open',
      location: map['location'] != null
          ? LocationModel.fromMap(map['location'])
          : null,
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : null,
      createdAt: _parseFlexibleDateTime(
        map['createdAt'] ?? map['lastUpdated'] ?? map['resolvedAt'],
      ),
      resolvedAt: _parseFlexibleNullableDateTime(
        map['resolvedAt'] ?? map['closedAt'],
      ),
      assignedTo: map['assignedTo'],
      resolutionNotes: map['resolutionNotes'],
    );
  }

  ReportModel copyWith({
    String? id,
    String? reporterId,
    String? title,
    String? description,
    String? type,
    String? priority,
    String? status,
    LocationModel? location,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? assignedTo,
    String? resolutionNotes,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      location: location ?? this.location,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      assignedTo: assignedTo ?? this.assignedTo,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }
}

/// Statistics Model for analytics
class StatisticsModel {
  final String? id;
  final DateTime date;
  final int totalPickupsCompleted;
  final int totalPickupsPending;
  final double totalWasteCollected; // in kg
  final Map<String, double> wasteByCategory; // Category -> weight
  final int activeDrivers;
  final int activeCitizens;
  final double averageResponseTime; // in hours
  final int reportsOpen;
  final int reportsResolved;

  StatisticsModel({
    this.id,
    required this.date,
    this.totalPickupsCompleted = 0,
    this.totalPickupsPending = 0,
    this.totalWasteCollected = 0.0,
    this.wasteByCategory = const {},
    this.activeDrivers = 0,
    this.activeCitizens = 0,
    this.averageResponseTime = 0.0,
    this.reportsOpen = 0,
    this.reportsResolved = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'totalPickupsCompleted': totalPickupsCompleted,
      'totalPickupsPending': totalPickupsPending,
      'totalWasteCollected': totalWasteCollected,
      'wasteByCategory': wasteByCategory,
      'activeDrivers': activeDrivers,
      'activeCitizens': activeCitizens,
      'averageResponseTime': averageResponseTime,
      'reportsOpen': reportsOpen,
      'reportsResolved': reportsResolved,
    };
  }

  factory StatisticsModel.fromMap(Map<String, dynamic> map, String documentId) {
    return StatisticsModel(
      id: documentId,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalPickupsCompleted: map['totalPickupsCompleted'] ?? 0,
      totalPickupsPending: map['totalPickupsPending'] ?? 0,
      totalWasteCollected: (map['totalWasteCollected'] ?? 0.0).toDouble(),
      wasteByCategory: Map<String, double>.from(
        (map['wasteByCategory'] ?? {}).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      ),
      activeDrivers: map['activeDrivers'] ?? 0,
      activeCitizens: map['activeCitizens'] ?? 0,
      averageResponseTime: (map['averageResponseTime'] ?? 0.0).toDouble(),
      reportsOpen: map['reportsOpen'] ?? 0,
      reportsResolved: map['reportsResolved'] ?? 0,
    );
  }
}
