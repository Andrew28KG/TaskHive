import 'package:flutter/material.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/screens/bee_detail_screen.dart';
import 'package:intl/intl.dart';

class UpcomingTasksPage extends StatefulWidget {
  final List<BeeTask> tasks;
  final VoidCallback onTaskUpdated;

  const UpcomingTasksPage({
    super.key,
    required this.tasks,
    required this.onTaskUpdated,
  });

  @override
  State<UpcomingTasksPage> createState() => _UpcomingTasksPageState();
}

class _UpcomingTasksPageState extends State<UpcomingTasksPage> {
  String _sortBy = 'date';
  String _filterBy = 'all';
  List<BeeTask> _filteredTasks = [];

  @override
  void initState() {
    super.initState();
    _filteredTasks = List.from(widget.tasks);
  }

  @override
  Widget build(BuildContext context) {
    // Apply sorting and filtering
    List<BeeTask> sortedTasks = List.from(_filteredTasks);
    
    // Sort tasks
    if (_sortBy == 'date') {
      sortedTasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    } else if (_sortBy == 'priority') {
      sortedTasks.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    }
    
    // Filter tasks
    if (_filterBy != 'all') {
      sortedTasks = sortedTasks.where((task) {
        if (_filterBy == 'todo') return task.status == BeeStatus.todo;
        if (_filterBy == 'inProgress') return task.status == BeeStatus.inProgress;
        if (_filterBy == 'done') return task.status == BeeStatus.done;
        return true;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Upcoming Tasks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(
                        value: 'date',
                        child: Text('Sort by Date'),
                      ),
                      DropdownMenuItem(
                        value: 'priority',
                        child: Text('Sort by Priority'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                          _sortTasks();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filterBy,
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Tasks'),
                      ),
                      DropdownMenuItem(
                        value: 'todo',
                        child: Text('To Do'),
                      ),
                      DropdownMenuItem(
                        value: 'inProgress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'done',
                        child: Text('Done'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _filterBy = value;
                          _filterTasks();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: sortedTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: sortedTasks.length,
              itemBuilder: (context, index) {
                final task = sortedTasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Container(
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
                    title: Text(task.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM d, y').format(task.dueDate!),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildStatusChip(task.status),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BeeDetailScreen(taskId: task.id),
                        ),
                      );
                      widget.onTaskUpdated();
                    },
                  ),
                );
              },
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
    IconData icon;

    switch (status) {
      case BeeStatus.todo:
        color = Colors.orange;
        label = 'To Do';
        icon = Icons.emoji_nature;
        break;
      case BeeStatus.inProgress:
        color = Colors.blue;
        label = 'In Progress';
        icon = Icons.local_florist;
        break;
      case BeeStatus.done:
        color = Colors.green;
        label = 'Done';
        icon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _sortTasks() {
    setState(() {
      _filteredTasks.sort((a, b) {
        if (_sortBy == 'date') {
          return a.dueDate!.compareTo(b.dueDate!);
        } else {
          // Sort by priority (queen > warrior > worker)
          final priorityOrder = {
            BeePriority.queen: 3,
            BeePriority.warrior: 2,
            BeePriority.worker: 1,
          };
          return priorityOrder[b.priority]!.compareTo(priorityOrder[a.priority]!);
        }
      });
    });
  }

  void _filterTasks() {
    setState(() {
      _filteredTasks = widget.tasks.where((task) {
        if (_filterBy == 'all') return true;
        return task.status.toString().split('.').last == _filterBy;
      }).toList();
      _sortTasks();
    });
  }
} 