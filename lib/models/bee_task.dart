import 'package:cloud_firestore/cloud_firestore.dart';

enum BeePriority {
  worker, // Low priority
  warrior, // Medium priority
  queen // High priority
}

enum BeeStatus {
  todo,
  inProgress,
  done
}

class BeeTask {
  final String id;
  final String hiveId;
  final String title;
  final String description;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? dueDate;
  final BeePriority priority;
  final BeeStatus status;
  final List<String> attachments;
  final List<Comment> comments;
  final List<String> tags;
  final String teamId;

  BeeTask({
    required this.id,
    required this.hiveId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.createdAt,
    this.updatedAt,
    this.dueDate,
    this.priority = BeePriority.worker,
    this.status = BeeStatus.todo,
    this.attachments = const [],
    this.comments = const [],
    this.tags = const [],
    required this.teamId,
  });

  factory BeeTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BeeTask(
      id: doc.id,
      hiveId: data['hiveId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      priority: BeePriority.values.firstWhere(
        (e) => e.toString() == 'BeePriority.${data['priority'] ?? 'worker'}',
        orElse: () => BeePriority.worker,
      ),
      status: BeeStatus.values.firstWhere(
        (e) => e.toString() == 'BeeStatus.${data['status'] ?? 'todo'}',
        orElse: () => BeeStatus.todo,
      ),
      attachments: List<String>.from(data['attachments'] ?? []),
      comments: (data['comments'] as List<dynamic>? ?? [])
          .map((c) => Comment.fromMap(c as Map<String, dynamic>))
          .toList(),
      tags: List<String>.from(data['tags'] ?? []),
      teamId: data['teamId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hiveId': hiveId,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'attachments': attachments,
      'comments': comments.map((c) => c.toMap()).toList(),
      'tags': tags,
      'teamId': teamId,
    };
  }

  BeeTask copyWith({
    String? title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    BeePriority? priority,
    BeeStatus? status,
    List<String>? attachments,
    List<Comment>? comments,
    List<String>? tags,
    DateTime? updatedAt,
    String? teamId,
  }) {
    return BeeTask(
      id: id,
      hiveId: hiveId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
      tags: tags ?? this.tags,
      teamId: teamId ?? this.teamId,
    );
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class TaskComment {
  final String text;
  final String author;
  final DateTime timestamp;

  TaskComment({
    required this.text,
    required this.author,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'author': author,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory TaskComment.fromMap(Map<String, dynamic> map) {
    return TaskComment(
      text: map['text'] as String,
      author: map['author'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
} 