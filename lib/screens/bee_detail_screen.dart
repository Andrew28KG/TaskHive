import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/main.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taskhive/utils/tutorial_manager.dart';

class BeeDetailScreen extends StatefulWidget {
  final String taskId;

  const BeeDetailScreen({super.key, required this.taskId});

  @override
  State<BeeDetailScreen> createState() => _BeeDetailScreenState();
}

class _BeeDetailScreenState extends State<BeeDetailScreen> {
  bool _isLoading = true;
  BeeTask? _task;
  String? _assignedUserEmail;
  final _commentController = TextEditingController();
  bool _isTeamCreator = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
    
    // Add this to show the task tutorial after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTaskDetailTutorial();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .get();

      if (doc.exists) {
        // Check if user is team creator
        final teamId = doc.data()?['teamId'];
        if (teamId != null) {
          final teamDoc = await FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .get();
          _isTeamCreator = teamDoc.data()?['createdBy'] == currentUserId;
        }

        // Load assigned user's email
        final assignedUserId = doc.data()?['assignedTo'];
        if (assignedUserId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(assignedUserId)
              .get();
          _assignedUserEmail = userDoc.data()?['email'];
        }

        setState(() {
          _task = BeeTask.fromFirestore(doc);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task not found')),
          );
        }
      }
    } catch (e) {
      print('Error loading task: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTaskEmail() async {
    if (_task == null || _assignedUserEmail == null) return;

    final subject = '[TaskHive] Task Assignment: ${_task!.title}';
    final body = '''Hi there,

A task has been assigned to you in TaskHive.

Task Details:
-------------
Title: ${_task!.title}
Description: ${_task!.description}
Priority: ${_getPriorityText()}
${_task!.dueDate != null ? 'Due Date: ${DateFormat('EEEE, MMMM d, y').format(
        _task!.dueDate!)}\n' : ''}Status: ${_task!
        .status
        .toString()
        .split('.')
        .last
        .toUpperCase()}

Please review this task and update its status as you make progress.
You can access the task directly through the TaskHive app.

Best regards,
TaskHive Team

Note: This is an automated notification. Please do not reply to this email.''';

    try {
      final emailUri = Uri(
        scheme: 'mailto',
        path: _assignedUserEmail,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri
            .encodeComponent(body)}',
      );

      if (!await launchUrl(emailUri)) {
        throw Exception('Could not launch email client');
      }
    } catch (e) {
      print('Error launching email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open email. Please check if you have an email app installed.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_task?.title ?? 'Bee Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'View Tutorial',
            onPressed: () {
              TutorialManager.replayTutorial(
                context, 
                TutorialManager.keyTask
              );
            },
          ),
          if (_isTeamCreator) ...[
            if (_assignedUserEmail != null)
              IconButton(
                icon: const Icon(Icons.notifications_active),
                onPressed: _sendTaskEmail,
                tooltip: 'Send Task Notification',
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditTaskDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteTaskDialog,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_task == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaskHeader(),
          const SizedBox(height: 24),
          _buildTaskDetails(),
          const SizedBox(height: 24),
          _buildStatusSection(),
          const SizedBox(height: 24),
          _buildCommentsSection(),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getPriorityColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getPriorityIcon(),
                    color: _getPriorityColor(),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _task!.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_task!.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _task!.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskDetails() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Task Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailItem(
              Icons.person,
              'Assigned To',
              _buildAssignedMember(),
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildDetailItem(
              Icons.local_florist,
              'Priority',
              Text(
                _getPriorityText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _getPriorityColor(),
            ),
            const SizedBox(height: 12),
            _buildDetailItem(
              Icons.calendar_today,
              'Due Date',
              Text(
                _task!.dueDate != null
                    ? DateFormat('MMM d, y').format(_task!.dueDate!)
                    : 'No due date',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildDetailItem(
              Icons.access_time,
              'Created',
              Text(
                DateFormat('MMM d, y').format(_task!.createdAt),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Colors.grey,
            ),
            if (_task!.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _task!.tags.map((tag) =>
                    Chip(
                      label: Text(tag),
                      backgroundColor: Colors.amber.withOpacity(0.1),
                      labelStyle: TextStyle(color: Colors.amber[700]),
                    )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedMember() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(_task!.assignedTo)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('Loading...');
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['name'] as String? ?? 'Unknown User';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person,
              size: 14,
              color: Theme
                  .of(context)
                  .brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              userName,
              style: TextStyle(
                color: Theme
                    .of(context)
                    .brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, Widget content,
      Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              content,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  color: Colors.purple[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusButton(
                  BeeStatus.todo,
                  Icons.emoji_nature,
                  'To Do',
                  Colors.orange,
                ),
                _buildStatusButton(
                  BeeStatus.inProgress,
                  Icons.local_florist,
                  'Busy Bee',
                  Colors.blue,
                ),
                _buildStatusButton(
                  BeeStatus.done,
                  Icons.check_circle,
                  'Done',
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(BeeStatus status, IconData icon, String label,
      Color color) {
    final isSelected = _task!.status == status;
    final canChangeStatus = _isTeamCreator ||
        _task!.assignedTo == currentUserId;

    return InkWell(
      onTap: canChangeStatus ? () => _updateTaskStatus(status) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.green[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bee Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_task!.comments.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.chat,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No comments yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _task!.comments.length,
                itemBuilder: (context, index) {
                  final comment = _task!.comments[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(comment.userName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comment.text),
                        Text(
                          DateFormat('MMM d, y - h:mm a').format(
                              comment.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    minLines: 2,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addComment,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor() {
    switch (_task!.priority) {
      case BeePriority.worker:
        return Colors.blue;
      case BeePriority.warrior:
        return Colors.orange;
      case BeePriority.queen:
        return Colors.red;
    }
  }

  IconData _getPriorityIcon() {
    switch (_task!.priority) {
      case BeePriority.worker:
        return Icons.emoji_nature;
      case BeePriority.warrior:
        return Icons.local_fire_department;
      case BeePriority.queen:
        return Icons.stars;
    }
  }

  String _getPriorityText() {
    switch (_task!.priority) {
      case BeePriority.worker:
        return 'Worker Bee (Regular)';
      case BeePriority.warrior:
        return 'Warrior Bee (Urgent)';
      case BeePriority.queen:
        return 'Queen Bee (Important)';
    }
  }

  Future<void> _updateTaskStatus(BeeStatus newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({
        'status': newStatus
            .toString()
            .split('.')
            .last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _loadTask();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task marked as ${newStatus
                .toString()
                .split('.')
                .last}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      // Get the current user's document to get their username
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      // Get the username as a non-nullable String
      final userData = userDoc.data();
      final userName = userData != null && userData['name'] is String
          ? userData['name'] as String
          : 'Unknown User';

      final comments = [..._task!.comments];
      comments.add(
        Comment(
          id: DateTime
              .now()
              .millisecondsSinceEpoch
              .toString(),
          userId: currentUserId ?? '',
          userName: userName,
          text: _commentController.text,
          createdAt: DateTime.now(),
        ),
      );

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({
        'comments': comments.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      _loadTask();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: ${e.toString()}')),
        );
      }
    }
  }

  void _showEditTaskDialog() {
    final titleController = TextEditingController(text: _task!.title);
    final descriptionController = TextEditingController(
        text: _task!.description);
    String selectedPriority = _task!
        .priority
        .toString()
        .split('.')
        .last;
    DateTime? selectedDueDate = _task!.dueDate;
    String? selectedMemberId = _task!.assignedTo;

    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setState) =>
                AlertDialog(
                  title: const Text('Edit Task'),
                  content: SizedBox(
                    width: MediaQuery
                        .of(context)
                        .size
                        .width * 0.9,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('teams')
                                .doc(_task!.teamId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }

                              final teamData = snapshot.data!.data() as Map<
                                  String,
                                  dynamic>;
                              final members = List<String>.from(
                                  teamData['members'] ?? []);

                              return FutureBuilder<List<DocumentSnapshot>>(
                                future: Future.wait(
                                  members.map((id) =>
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(id)
                                          .get()),
                                ),
                                builder: (context, userSnapshot) {
                                  if (!userSnapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }

                                  final users = userSnapshot.data!;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assigned To',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text('Select Assignee'),
                                                content: SizedBox(
                                                  width: double.maxFinite,
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: users.length,
                                                    itemBuilder: (context, index) {
                                                      final user = users[index];
                                                      final userData = user.data() as Map<String, dynamic>;
                                                      final userName = userData['name'] ?? 'Unknown User';
                                                      
                                                      return ListTile(
                                                        leading: CircleAvatar(
                                                          child: Text(userName[0].toUpperCase()),
                                                        ),
                                                        title: Text(userName),
                                                        trailing: selectedMemberId == user.id 
                                                            ? const Icon(Icons.check_circle, color: Colors.green)
                                                            : null,
                                                        onTap: () {
                                                          setState(() {
                                                            selectedMemberId = user.id;
                                                          });
                                                          Navigator.pop(context);
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('Cancel'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade400),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            children: [
                                              Builder(
                                                builder: (context) {
                                                  // Find selected user
                                                  String displayName = 'Select a team member';
                                                  for (var user in users) {
                                                    if (user.id == selectedMemberId) {
                                                      final userData = user.data() as Map<String, dynamic>;
                                                      displayName = userData['name'] ?? 'Unknown User';
                                                      break;
                                                    }
                                                  }
                                                  
                                                  return Expanded(
                                                    child: Text(
                                                      displayName,
                                                      style: const TextStyle(fontSize: 16),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                },
                                              ),
                                              const Icon(Icons.arrow_drop_down),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedPriority,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'worker',
                                child: Text('Worker Bee'),
                              ),
                              DropdownMenuItem(
                                value: 'warrior',
                                child: Text('Warrior Bee'),
                              ),
                              DropdownMenuItem(
                                value: 'queen',
                                child: Text('Queen Bee'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedPriority = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            title: Text(
                              selectedDueDate == null
                                  ? 'No due date'
                                  : DateFormat('MMM d, y').format(
                                  selectedDueDate!),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDueDate ?? now,
                                      firstDate: now.subtract(
                                          const Duration(days: 365)),
                                      lastDate: now.add(
                                          const Duration(days: 365)),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        selectedDueDate = date;
                                      });
                                    }
                                  },
                                ),
                                if (selectedDueDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        selectedDueDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter a title')),
                          );
                          return;
                        }

                        try {
                          await FirebaseFirestore.instance
                              .collection('tasks')
                              .doc(widget.taskId)
                              .update({
                            'title': titleController.text.trim(),
                            'description': descriptionController.text.trim(),
                            'priority': selectedPriority,
                            'dueDate': selectedDueDate != null ? Timestamp
                                .fromDate(selectedDueDate!) : null,
                            'assignedTo': selectedMemberId,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            _loadTask();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating task: ${e
                                  .toString()}')),
                            );
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showDeleteTaskDialog() {
    final deleteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone.',
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type DELETE to confirm:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: deleteController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type DELETE',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (deleteController.text != 'DELETE') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please type DELETE to confirm')),
                    );
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection('tasks')
                        .doc(widget.taskId)
                        .delete();

                    if (mounted) {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Go back to previous screen

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Task deleted successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                            'Error deleting task: ${e.toString()}')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // Add this method to show the task detail tutorial
  Future<void> _showTaskDetailTutorial() async {
    if (!mounted) return;
    
    await TutorialManager.showTutorialDialog(
      context,
      TutorialManager.keyTask,
      'Task Details',
      TutorialManager.getTaskDetailsTutorialSteps(),
    );
  }
}
