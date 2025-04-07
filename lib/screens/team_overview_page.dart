import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/models/project.dart';
import 'package:intl/intl.dart';

class TeamOverviewPage extends StatefulWidget {
  final String teamId;
  const TeamOverviewPage({super.key, required this.teamId});

  @override
  State<TeamOverviewPage> createState() => _TeamOverviewPageState();
}

class _TeamOverviewPageState extends State<TeamOverviewPage> {
  bool _isLoading = true;
  List<Project> _projects = [];
  Map<String, List<BeeTask>> _projectTasks = {};
  Map<String, int> _completedTasksCount = {};
  Map<String, int> _totalTasksCount = {};
  List<dynamic> _topPerformers = [];

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    setState(() => _isLoading = true);
    try {
      // Load team data with members
      final teamSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();
      
      final teamData = teamSnapshot.data();
      final memberIds = teamData != null ? 
          (teamData['members'] is Map ? 
              (teamData['members'] as Map).keys.cast<String>().toList() : 
              <String>[]) : 
          <String>[];
      
      // Load projects
      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('teamId', isEqualTo: widget.teamId)
          .get();

      _projects = projectsSnapshot.docs
          .map((doc) => Project.fromFirestore(doc))
          .toList();

      // Load tasks for each project and calculate metrics
      Map<String, int> memberTaskCounts = {};
      Map<String, int> memberCompletedTaskCounts = {};
      
      for (final project in _projects) {
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('tasks')
            .where('hiveId', isEqualTo: project.id)
            .get();

        final tasks = tasksSnapshot.docs
            .map((doc) => BeeTask.fromFirestore(doc))
            .toList();

        // Count tasks by assignee
        for (final task in tasks) {
          if (task.assignedTo != null && task.assignedTo!.isNotEmpty) {
            memberTaskCounts[task.assignedTo!] = (memberTaskCounts[task.assignedTo!] ?? 0) + 1;
            if (task.status == BeeStatus.done) {
              memberCompletedTaskCounts[task.assignedTo!] = (memberCompletedTaskCounts[task.assignedTo!] ?? 0) + 1;
            }
          }
        }

        _projectTasks[project.id] = tasks;
        _completedTasksCount[project.id] = tasks
            .where((task) => task.status == BeeStatus.done)
            .length;
        _totalTasksCount[project.id] = tasks.length;
      }

      // Calculate top performers
      _topPerformers = memberIds
          .where((id) => memberTaskCounts[id] != null && memberTaskCounts[id]! > 0)
          .map((id) {
            final totalTasks = memberTaskCounts[id] ?? 0;
            final completedTasks = memberCompletedTaskCounts[id] ?? 0;
            final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;
            return {
              'id': id,
              'totalTasks': totalTasks,
              'completedTasks': completedTasks,
              'completionRate': completionRate,
            };
          })
          .toList()
          ..sort((a, b) => (b['completionRate'] as double).compareTo(a['completionRate'] as double));

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading team data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Overview'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeamPerformanceCard(),
                  const SizedBox(height: 24),
                  _buildTeamInsights(),
                  const SizedBox(height: 24),
                  _buildProjectsOverview(),
                ],
              ),
            ),
    );
  }

  Widget _buildTeamPerformanceCard() {
    // Calculate overall team performance metrics
    int totalTasks = 0;
    int completedTasks = 0;
    int inProgressTasks = 0;
    int overdueTasks = 0;

    for (final project in _projects) {
      final tasks = _projectTasks[project.id] ?? [];
      totalTasks += tasks.length;
      completedTasks += tasks.where((task) => task.status == BeeStatus.done).length;
      inProgressTasks += tasks.where((task) => task.status == BeeStatus.inProgress).length;
      overdueTasks += tasks.where((task) {
        final now = DateTime.now();
        return task.dueDate != null && 
               task.dueDate!.isBefore(now) && 
               task.status != BeeStatus.done;
      }).length;
    }

    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;
    final onTimeRate = totalTasks > 0 ? ((totalTasks - overdueTasks) / totalTasks * 100) : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Performance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Tasks',
                    totalTasks.toString(),
                    Icons.task,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Completed',
                    completedTasks.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'In Progress',
                    inProgressTasks.toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Overdue',
                    overdueTasks.toString(),
                    Icons.warning,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProgressSection('Completion Rate', completionRate, Colors.green),
            const SizedBox(height: 16),
            _buildProgressSection('Tasks On Time', onTimeRate, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamInsights() {
    // Calculate insights
    int totalTasks = 0;
    int completedTasks = 0;
    int overdueTasks = 0;
    int todoTasks = 0;
    int inProgressTasks = 0;
    
    // Track dates for timeline analysis
    final DateTime now = DateTime.now();
    final DateTime oneWeekAgo = now.subtract(const Duration(days: 7));
    int tasksCompletedThisWeek = 0;
    int tasksCreatedThisWeek = 0;
    
    // Due dates
    int tasksWithDueDates = 0;
    int tasksWithoutDueDates = 0;

    for (final project in _projects) {
      final tasks = _projectTasks[project.id] ?? [];
      totalTasks += tasks.length;
      completedTasks += tasks.where((task) => task.status == BeeStatus.done).length;
      todoTasks += tasks.where((task) => task.status == BeeStatus.todo).length;
      inProgressTasks += tasks.where((task) => task.status == BeeStatus.inProgress).length;
      
      // Timeline analysis
      for (final task in tasks) {
        if (task.status == BeeStatus.done && 
            task.updatedAt != null && 
            task.updatedAt!.isAfter(oneWeekAgo)) {
          tasksCompletedThisWeek++;
        }
        
        if (task.createdAt.isAfter(oneWeekAgo)) {
          tasksCreatedThisWeek++;
        }
        
        // Due date analysis
        if (task.dueDate != null) {
          tasksWithDueDates++;
          if (task.dueDate!.isBefore(now) && task.status != BeeStatus.done) {
            overdueTasks++;
          }
        } else {
          tasksWithoutDueDates++;
        }
      }
    }

    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;
    final weeklyCompletionRate = tasksCreatedThisWeek > 0 ? 
        (tasksCompletedThisWeek / tasksCreatedThisWeek * 100) : 0.0;
    final dueDateUsage = totalTasks > 0 ? (tasksWithDueDates / totalTasks * 100) : 0.0;

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
                  Icons.lightbulb,
                  color: Colors.amber[700],
                ),
                const SizedBox(width: 8),
                const Text(
                  'Team Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getInsightMessage(completionRate),
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            
            // Additional insights based on the data
            if (tasksCreatedThisWeek > 0) ...[
              Text(
                '📊 Weekly Progress: ${weeklyCompletionRate.toStringAsFixed(1)}% of tasks created this week are completed',
                style: TextStyle(
                  fontSize: 14,
                  color: weeklyCompletionRate >= 50 ? Colors.green[700] : Colors.orange[700],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Task distribution
            Text(
              '📋 Task Distribution: ${todoTasks} To Do, ${inProgressTasks} In Progress, ${completedTasks} Completed',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            
            // Due date usage insights
            Text(
              '📅 ${dueDateUsage.toStringAsFixed(1)}% of tasks have due dates assigned',
              style: TextStyle(
                fontSize: 14,
                color: dueDateUsage >= 70 ? Colors.green[700] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            
            if (overdueTasks > 0) ...[
              Text(
                '⚠️ There are $overdueTasks overdue tasks that need attention',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Action items based on analysis
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Suggested Actions:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            ...(_getSuggestedActions(
              completionRate: completionRate,
              overdueTasks: overdueTasks,
              todoTasks: todoTasks,
              inProgressTasks: inProgressTasks,
              dueDateUsage: dueDateUsage,
            )),
          ],
        ),
      ),
    );
  }

  List<Widget> _getSuggestedActions({
    required double completionRate,
    required int overdueTasks,
    required int todoTasks,
    required int inProgressTasks,
    required double dueDateUsage,
  }) {
    final List<Widget> actions = [];
    
    // Based on completion rate
    if (completionRate < 40) {
      actions.add(_buildActionItem(
        'Focus on completing existing tasks before taking on new ones',
        Icons.task_alt,
      ));
    }
    
    // Based on overdue tasks
    if (overdueTasks > 0) {
      actions.add(_buildActionItem(
        'Address the ${overdueTasks} overdue tasks as a priority',
        Icons.warning,
      ));
    }
    
    // Too many in-progress tasks
    if (inProgressTasks > todoTasks && inProgressTasks > 3) {
      actions.add(_buildActionItem(
        'Too many tasks in progress. Consider completing some before starting new ones',
        Icons.hourglass_top,
      ));
    }
    
    // Low due date usage
    if (dueDateUsage < 50) {
      actions.add(_buildActionItem(
        'Add due dates to more tasks to improve tracking and timeliness',
        Icons.event,
      ));
    }
    
    // No actions needed
    if (actions.isEmpty) {
      actions.add(_buildActionItem(
        'Keep up the good work! The team is well-organized and making good progress',
        Icons.thumb_up,
      ));
    }
    
    return actions;
  }
  
  Widget _buildActionItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInsightMessage(double completionRate) {
    if (completionRate >= 85) {
      return 'Outstanding team performance! The team is excelling and delivering exceptional results. 🌟';
    } else if (completionRate >= 70) {
      return 'Great work! The team is demonstrating high efficiency and solid collaboration skills. 👏';
    } else if (completionRate >= 55) {
      return 'Good progress! The team is working well together and maintaining steady momentum. 👍';
    } else if (completionRate >= 40) {
      return 'The team is making progress. Focus on completing more tasks to improve performance. 💪';
    } else if (completionRate >= 25) {
      return 'The team is showing some progress. Consider reviewing workflows to increase productivity. 🔄';
    } else {
      return 'Team is getting started. Let\'s work together to build momentum! 🚀';
    }
  }

  Widget _buildProjectsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Projects Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._projects.map((project) {
          final tasks = _projectTasks[project.id] ?? [];
          final completedTasks = tasks.where((task) => task.status == BeeStatus.done).length;
          final progress = tasks.isNotEmpty ? completedTasks / tasks.length : 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedTasks/${tasks.length} tasks completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
} 