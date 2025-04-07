import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/main.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/screens/focus_timer_page.dart';

class FocusScreen extends StatefulWidget {
  final String? teamId;
  const FocusScreen({super.key, this.teamId});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _isLoading = true;
  List<BeeTask> _tasks = [];
  String? _currentTeamId;

  @override
  void initState() {
    super.initState();
    _currentTeamId = widget.teamId;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      if (_currentTeamId == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        _currentTeamId = userDoc.data()?['currentTeamId'];
      }

      if (_currentTeamId == null) {
        setState(() {
          _tasks = [];
          _isLoading = false;
        });
        return;
      }

      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('teamId', isEqualTo: _currentTeamId)
          .where('assignedTo', isEqualTo: currentUserId)
          .where('status', whereIn: ['todo', 'inProgress'])
          .get();

      setState(() {
        _tasks = tasksSnapshot.docs
            .map((doc) => BeeTask.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildFocusList(),
    );
  }

  Widget _buildFocusList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : CustomScrollView(
            slivers: [
              // Focus Header
              SliverAppBar(
                expandedHeight: 80,
                pinned: true,
                elevation: 0,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.deepOrange.shade900
                  : Colors.orange.shade400,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Focus Mode',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  centerTitle: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _tasks.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks available for focus',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create tasks in your team to start focusing',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildTaskCard(_tasks[index]),
                          childCount: _tasks.length,
                        ),
                      ),
              ),
            ],
          );
  }

  Widget _buildTaskCard(BeeTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FocusTimerPage(task: task),
            ),
          ).then((_) {
            // Refresh tasks when returning from the focus timer page
            _loadTasks();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task.priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getPriorityIcon(task.priority),
                      color: _getPriorityColor(task.priority),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusChip(task.status),
                  const SizedBox(width: 8),
                  if (task.dueDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[300]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, y').format(task.dueDate!),
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[300]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(BeePriority priority) {
    switch (priority) {
      case BeePriority.worker:
        return Colors.blue;
      case BeePriority.warrior:
        return Colors.orange;
      case BeePriority.queen:
        return Colors.red;
    }
  }

  IconData _getPriorityIcon(BeePriority priority) {
    switch (priority) {
      case BeePriority.worker:
        return Icons.work;
      case BeePriority.warrior:
        return Icons.local_fire_department;
      case BeePriority.queen:
        return Icons.star;
    }
  }

  Widget _buildStatusChip(BeeStatus status) {
    Color color;
    String label;

    switch (status) {
      case BeeStatus.todo:
        color = Colors.grey;
        label = 'To Do';
        break;
      case BeeStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        break;
      case BeeStatus.done:
        color = Colors.green;
        label = 'Done';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 