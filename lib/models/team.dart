import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamRole {
  owner,
  admin,
  member,
}

class Team {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, TeamRole> members;
  final List<String> pendingInvites;

  Team({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.members,
    required this.pendingInvites,
  });

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    print('Parsing team data: ${doc.id}');
    
    // Handle potential null values for createdAt
    DateTime createdAt;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else {
        print('Warning: createdAt is not a Timestamp: ${data['createdAt']}');
        createdAt = DateTime.now();
      }
    } else {
      print('Warning: createdAt is null');
      createdAt = DateTime.now();
    }
    
    // Handle potential null values for updatedAt
    DateTime? updatedAt;
    if (data['updatedAt'] != null) {
      if (data['updatedAt'] is Timestamp) {
        updatedAt = (data['updatedAt'] as Timestamp).toDate();
      } else {
        print('Warning: updatedAt is not a Timestamp: ${data['updatedAt']}');
      }
    }
    
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      members: _parseMembers(data['members'] ?? {}),
      pendingInvites: List<String>.from(data['pendingInvites'] ?? []),
    );
  }

  static Map<String, TeamRole> _parseMembers(Map<String, dynamic> membersData) {
    final Map<String, TeamRole> result = {};
    
    print('Parsing members data: $membersData');
    
    if (membersData.isEmpty) {
      print('Warning: members data is empty');
      return result;
    }
    
    membersData.forEach((userId, roleString) {
      if (roleString == null) {
        print('Warning: role is null for user $userId');
        result[userId] = TeamRole.member;
      } else {
        result[userId] = _parseRole(roleString.toString());
      }
    });
    
    return result;
  }

  static TeamRole _parseRole(String roleString) {
    switch (roleString) {
      case 'owner':
        return TeamRole.owner;
      case 'admin':
        return TeamRole.admin;
      case 'member':
      default:
        return TeamRole.member;
    }
  }

  Map<String, dynamic> toMap() {
    final Map<String, String> membersMap = {};
    
    members.forEach((userId, role) {
      membersMap[userId] = role.toString().split('.').last;
    });
    
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'members': membersMap,
      'pendingInvites': pendingInvites,
    };
  }

  Team copyWith({
    String? name,
    String? description,
    DateTime? updatedAt,
    Map<String, TeamRole>? members,
    List<String>? pendingInvites,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      pendingInvites: pendingInvites ?? this.pendingInvites,
    );
  }
} 