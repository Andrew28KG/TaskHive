import 'package:cloud_firestore/cloud_firestore.dart';

enum HiveStatus {
  active,
  paused,
  completed,
  archived
}

class HiveProject {
  final String id;
  final String name;
  final String description;
  final String teamId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final HiveStatus status;
  final List<String> members;

  HiveProject({
    required this.id,
    required this.name,
    required this.description,
    required this.teamId,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.status = HiveStatus.active,
    this.members = const [],
  });

  factory HiveProject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HiveProject(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      teamId: data['teamId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      status: HiveStatus.values.firstWhere(
        (e) => e.toString() == 'HiveStatus.${data['status'] ?? 'active'}',
        orElse: () => HiveStatus.active,
      ),
      members: List<String>.from(data['members'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'teamId': teamId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status.toString().split('.').last,
      'members': members,
    };
  }

  HiveProject copyWith({
    String? name,
    String? description,
    String? teamId,
    DateTime? updatedAt,
    HiveStatus? status,
    List<String>? members,
  }) {
    return HiveProject(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      teamId: teamId ?? this.teamId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      members: members ?? this.members,
    );
  }
} 