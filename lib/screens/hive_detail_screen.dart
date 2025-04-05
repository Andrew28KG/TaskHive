import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/models/hive_project.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/screens/bee_detail_screen.dart';
import 'package:taskhive/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/utils/tutorial_manager.dart';

class HiveDetailScreen extends StatefulWidget {
  final String projectId;

  const HiveDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<HiveDetailScreen> createState() => _HiveDetailScreenState();
}

class _HiveDetailScreenState extends State<HiveDetailScreen> {
  bool _isLoading = true;
  HiveProject? _project;
  List<BeeTask> _tasks = [];
  Map<BeeStatus, List<BeeTask>> _tasksByStatus = {};
  bool _isTeamCreator = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Add this to show the hive detail tutorial after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHiveDetailTutorial();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load project details
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (!projectDoc.exists) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hive not found')),
          );
        }
        return;
      }

      // Check if user is team creator
      final teamId = projectDoc.data()?['teamId'];
      if (teamId != null) {
        final teamDoc = await FirebaseFirestore.instance
            .collection('teams')
            .doc(teamId)
            .get();
        _isTeamCreator = teamDoc.data()?['createdBy'] == currentUserId;
      }

      // Load tasks for this project
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('hiveId', isEqualTo: widget.projectId)
          .get();

      final tasks = tasksSnapshot.docs
          .map((doc) => BeeTask.fromFirestore(doc))
          .toList();

      // Group tasks by status
      final tasksByStatus = <BeeStatus, List<BeeTask>>{};
      for (final status in BeeStatus.values) {
        tasksByStatus[status] = tasks
            .where((task) => task.status == status)
            .toList();
      }

      setState(() {
        _project = HiveProject.fromFirestore(projectDoc);
        _tasks = tasks;
        _tasksByStatus = tasksByStatus;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_project?.name ?? 'Hive Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'View Tutorial',
            onPressed: () {
              TutorialManager.replayTutorial(
                context, 
                TutorialManager.keyHive
              );
            },
          ),
          if (_isTeamCreator) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditProjectDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteHiveDialog,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: _isTeamCreator
          ? FloatingActionButton(
              onPressed: _showCreateTaskDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_project == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHiveHeader(),
          const SizedBox(height: 24),
          _buildHiveStatusSection(),
          const SizedBox(height: 24),
          _buildTaskStats(),
          const SizedBox(height: 24),
          _buildTaskSections(),
        ],
      ),
    );
  }

  Widget _buildHiveHeader() {
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.deepOrange[900]!.withOpacity(0.1)
                        : Colors.orange[400]!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.hive,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange
                        : Colors.orange[400],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _project!.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_project!.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _project!.description,
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
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHiveInfoItem(
                  Icons.calendar_today,
                  'Created',
                  _formatDate(_project!.createdAt),
                  Colors.blue,
                ),
                _buildHiveInfoItem(
                  Icons.local_florist,
                  'Active Bees',
                  _tasksByStatus[BeeStatus.inProgress]?.length.toString() ?? '0',
                  Colors.green,
                ),
                _buildHiveInfoItem(
                  Icons.emoji_nature,
                  'Total Bees',
                  _tasks.length.toString(),
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHiveInfoItem(IconData icon, String label, String value, Color color) {
    return Column(
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
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHiveStatusSection() {
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
                  Icons.hive,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange
                      : Colors.orange[400],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hive Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isTeamCreator)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[300]!,
                  ),
                ),
                child: DropdownButtonFormField<HiveStatus>(
                  value: _project!.status,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: HiveStatus.values.map((status) {
                    String label;
                    IconData icon;
                    Color color;

                    switch (status) {
                      case HiveStatus.active:
                        label = 'Active';
                        icon = Icons.play_arrow;
                        color = Colors.green[400]!;
                        break;
                      case HiveStatus.paused:
                        label = 'Paused';
                        icon = Icons.pause;
                        color = Colors.orange[400]!;
                        break;
                      case HiveStatus.completed:
                        label = 'Completed';
                        icon = Icons.check_circle;
                        color = Colors.blue[400]!;
                        break;
                      case HiveStatus.archived:
                        label = 'Archived';
                        icon = Icons.archive;
                        color = Colors.grey[400]!;
                        break;
                    }

                    return DropdownMenuItem<HiveStatus>(
                      value: status,
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(color: color),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateHiveStatus(value);
                    }
                  },
                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.white,
                ),
              )
            else
              _buildStatusDisplay(_project!.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDisplay(HiveStatus status) {
    String label;
    IconData icon;
    Color color;

    switch (status) {
      case HiveStatus.active:
        label = 'Active';
        icon = Icons.play_arrow;
        color = Colors.green[400]!;
        break;
      case HiveStatus.paused:
        label = 'Paused';
        icon = Icons.pause;
        color = Colors.orange[400]!;
        break;
      case HiveStatus.completed:
        label = 'Completed';
        icon = Icons.check_circle;
        color = Colors.blue[400]!;
        break;
      case HiveStatus.archived:
        label = 'Archived';
        icon = Icons.archive;
        color = Colors.grey[400]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateHiveStatus(HiveStatus newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _project = _project!.copyWith(status: newStatus);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hive status updated to ${newStatus.toString().split('.').last.toLowerCase()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating hive status: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildTaskStats() {
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
                  Icons.analytics,
                  color: Colors.purple[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Task Stats',
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
                _buildStatItem(
                  Icons.local_florist,
                  'In Progress',
                  _tasksByStatus[BeeStatus.inProgress]?.length.toString() ?? '0',
                  Colors.blue,
                ),
                _buildStatItem(
                  Icons.emoji_nature,
                  'To Do',
                  _tasksByStatus[BeeStatus.todo]?.length.toString() ?? '0',
                  Colors.orange,
                ),
                _buildStatItem(
                  Icons.check_circle,
                  'Completed',
                  _tasksByStatus[BeeStatus.done]?.length.toString() ?? '0',
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCount() {
    return _buildStatItem(
      Icons.group,
      'Members',
      _project!.members.length.toString(),
      Colors.green,
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
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
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.task_alt,
              color: Colors.blue[700],
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_tasks.isEmpty)
          _buildEmptyState()
        else
          Column(
            children: [
              _buildTaskList(
                'Busy Bees',
                _tasksByStatus[BeeStatus.inProgress]!,
                Icons.local_florist,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildTaskList(
                'Waiting Bees',
                _tasksByStatus[BeeStatus.todo]!,
                Icons.emoji_nature,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildTaskList(
                'Done Bees',
                _tasksByStatus[BeeStatus.done]!,
                Icons.check_circle,
                Colors.green,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTaskList(String title, List<BeeTask> tasks, IconData icon, Color color) {
    if (tasks.isEmpty) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = title == 'Busy Bees'
        ? Colors.blue[400]!
        : title == 'Waiting Bees'
            ? Colors.orange[400]!
            : Colors.green[400]!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  '$title (${tasks.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskItem(task);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BeeTask task) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getPriorityColor(task.priority).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getPriorityIcon(task.priority),
          color: _getPriorityColor(task.priority),
          size: 20,
        ),
      ),
      title: Text(
        task.title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(task.assignedTo)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData = snapshot.data?.data() as Map<String, dynamic>?;
                  final userName = userData?['name'] as String? ?? 'Unknown User';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            userName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (task.dueDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, y').format(task.dueDate!),
                        style: TextStyle(
                          color: Colors.grey[600],
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
      trailing: _isTeamCreator ? IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showTaskOptions(task),
      ) : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BeeDetailScreen(taskId: task.id),
          ),
        ).then((_) => _loadData());
      },
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.emoji_nature,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Bees in this Hive',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some tasks to get your bees buzzing!',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateTaskDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add First Task'),
            ),
          ],
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
        return Icons.emoji_nature;
      case BeePriority.warrior:
        return Icons.local_fire_department;
      case BeePriority.queen:
        return Icons.stars;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showTaskOptions(BeeTask task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_florist),
              title: const Text('Change Status'),
              trailing: DropdownButton<BeeStatus>(
                value: task.status,
                onChanged: (BeeStatus? newStatus) async {
                  if (newStatus != null) {
                    Navigator.pop(context);
                    await _updateTaskStatus(task, newStatus);
                  }
                },
                items: BeeStatus.values.map((status) {
                  String label;
                  IconData icon;
                  Color color;

                  switch (status) {
                    case BeeStatus.todo:
                      label = 'To Do';
                      icon = Icons.emoji_nature;
                      color = Colors.orange;
                      break;
                    case BeeStatus.inProgress:
                      label = 'In Progress';
                      icon = Icons.local_florist;
                      color = Colors.blue;
                      break;
                    case BeeStatus.done:
                      label = 'Done';
                      icon = Icons.check_circle;
                      color = Colors.green;
                      break;
                  }

                  return DropdownMenuItem<BeeStatus>(
                    value: status,
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(label),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_isTeamCreator) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Task'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BeeDetailScreen(taskId: task.id),
                    ),
                  ).then((_) => _loadData());
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Task', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteTaskDialog(task);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTaskDialog(BeeTask task) {
    final deleteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  const SnackBar(content: Text('Please type DELETE to confirm')),
                );
                return;
              }
              
              try {
                await FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(task.id)
                    .delete();
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting task: ${e.toString()}')),
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

  Future<void> _updateTaskStatus(BeeTask task, BeeStatus newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(task.id)
          .update({
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task marked as ${newStatus.toString().split('.').last}'),
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

  void _showCreateTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    BeePriority selectedPriority = BeePriority.worker;
    String? selectedAssignee;
    String? teamId;

    // Get the team ID and members for the current hive
    FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .get()
        .then((doc) async {
      teamId = doc.data()?['teamId'];
      if (teamId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Hive has no team assigned')),
        );
        return;
      }

      // Get team members
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .get();
      
      final teamData = teamDoc.data();
      if (teamData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Team not found')),
        );
        return;
      }

      final members = List<String>.from(teamData['members'] ?? []);
      final memberDocs = await Future.wait(
        members.map((id) => FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get()),
      );
      
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Add New Bee'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Task Title',
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
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Select Team Member'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: memberDocs.length,
                                    itemBuilder: (context, index) {
                                      final doc = memberDocs[index];
                                      final userData = doc.data() as Map<String, dynamic>?;
                                      final userName = userData?['name'] as String? ?? 'Unknown User';
                                      final isCreator = doc.id == teamData['createdBy'];
                                      
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isCreator ? Colors.amber[700] : Colors.grey[300],
                                          child: Icon(
                                            Icons.person,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(userName),
                                        subtitle: isCreator ? const Text('Team Host') : null,
                                        trailing: selectedAssignee == doc.id ? const Icon(Icons.check, color: Colors.green) : null,
                                        onTap: () {
                                          setState(() {
                                            selectedAssignee = doc.id;
                                          });
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Assign To',
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FutureBuilder<DocumentSnapshot>(
                                  future: selectedAssignee != null
                                      ? FirebaseFirestore.instance.collection('users').doc(selectedAssignee).get()
                                      : null,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Text('Loading...');
                                    }
                                    
                                    final userData = snapshot.data?.data() as Map<String, dynamic>?;
                                    final userName = userData?['name'] as String? ?? 'Select a team member';
                                    
                                    return Text(
                                      userName,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Due Date'),
                        subtitle: Text(
                          DateFormat('MMM d, y').format(selectedDate),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<BeePriority>(
                        value: selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: BeePriority.worker,
                            child: Text('Worker Bee (Regular)'),
                          ),
                          DropdownMenuItem(
                            value: BeePriority.warrior,
                            child: Text('Warrior Bee (Urgent)'),
                          ),
                          DropdownMenuItem(
                            value: BeePriority.queen,
                            child: Text('Queen Bee (Important)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedPriority = value;
                            });
                          }
                        },
                      ),
                    ],
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
                          const SnackBar(content: Text('Please enter a task title')),
                        );
                        return;
                      }

                      if (selectedAssignee == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a team member to assign the task')),
                        );
                        return;
                      }
                      
                      try {
                        // Create task with date only (no time)
                        final dueDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                        );
                        
                        await FirebaseFirestore.instance
                            .collection('tasks')
                            .add({
                          'hiveId': widget.projectId,
                          'teamId': teamId,
                          'title': titleController.text,
                          'description': descriptionController.text,
                          'assignedTo': selectedAssignee,
                          'userId': currentUserId,
                          'createdBy': currentUserId,
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                          'dueDate': Timestamp.fromDate(dueDate),
                          'priority': selectedPriority.toString().split('.').last,
                          'status': BeeStatus.todo.toString().split('.').last,
                          'attachments': [],
                          'comments': [],
                          'tags': [],
                        });
                        
                        if (mounted) {
                          Navigator.pop(context);
                          _loadData();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task created successfully')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error creating task: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    child: const Text('Create'),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  void _showEditProjectDialog() {
    if (_project == null) return;

    final nameController = TextEditingController(text: _project!.name);
    final descriptionController = TextEditingController(text: _project!.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Hive'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Hive Name',
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a hive name')),
                );
                return;
              }
              
              try {
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(widget.projectId)
                    .update({
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hive updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating hive: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteHiveDialog() {
    final deleteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hive'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All tasks in this hive will also be deleted.',
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
                  const SnackBar(content: Text('Please type DELETE to confirm')),
                );
                return;
              }
              
              try {
                // Delete all tasks in this hive
                final tasksSnapshot = await FirebaseFirestore.instance
                    .collection('tasks')
                    .where('hiveId', isEqualTo: widget.projectId)
                    .get();
                
                for (final doc in tasksSnapshot.docs) {
                  await doc.reference.delete();
                }
                
                // Delete the hive
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(widget.projectId)
                    .delete();
                
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hive deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting hive: ${e.toString()}')),
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

  Future<void> _showHiveDetailTutorial() async {
    if (!mounted) return;
    
    await TutorialManager.showTutorialDialog(
      context,
      TutorialManager.keyHive,
      'Hive Workspace',
      TutorialManager.getHiveDetailTutorialSteps(),
    );
  }
} 