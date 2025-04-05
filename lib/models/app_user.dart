import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final List<String> hives; // Projects/Hives the user is part of
  final Map<String, String> hiveRoles; // Project ID to role mapping
  final DateTime createdAt;
  final DateTime? lastActive;
  final Map<String, dynamic> settings;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.hives = const [],
    this.hiveRoles = const {},
    required this.createdAt,
    this.lastActive,
    this.settings = const {},
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      hives: List<String>.from(data['hives'] ?? []),
      hiveRoles: Map<String, String>.from(data['hiveRoles'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : null,
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'hives': hives,
      'hiveRoles': hiveRoles,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'settings': settings,
    };
  }

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    List<String>? hives,
    Map<String, String>? hiveRoles,
    DateTime? lastActive,
    Map<String, dynamic>? settings,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      hives: hives ?? this.hives,
      hiveRoles: hiveRoles ?? this.hiveRoles,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      settings: settings ?? this.settings,
    );
  }
} 