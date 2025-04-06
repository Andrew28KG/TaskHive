import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String teamId;
  final String createdBy;
  final DateTime createdAt;
  final List<String> attendees; // List of user IDs to attend the event
  final bool isOnlineMeeting; // Whether this is an online meeting
  final String location; // Meeting link for online or physical location for offline

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.teamId,
    required this.createdBy,
    required this.createdAt,
    required this.attendees,
    this.isOnlineMeeting = true,
    this.location = '',
  });

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      teamId: data['teamId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      attendees: List<String>.from(data['attendees'] ?? []),
      isOnlineMeeting: data['isOnlineMeeting'] ?? true,
      location: data['location'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'teamId': teamId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'attendees': attendees,
      'isOnlineMeeting': isOnlineMeeting,
      'location': location,
    };
  }

  Event copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? attendees,
    bool? isOnlineMeeting,
    String? location,
  }) {
    return Event(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      teamId: teamId,
      createdBy: createdBy,
      createdAt: createdAt,
      attendees: attendees ?? this.attendees,
      isOnlineMeeting: isOnlineMeeting ?? this.isOnlineMeeting,
      location: location ?? this.location,
    );
  }
} 