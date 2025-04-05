import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProgressDetailScreen extends StatefulWidget {
  final String hiveId;
  final String hiveName;
  final bool isTeamCreator;

  const ProgressDetailScreen({
    super.key,
    required this.hiveId,
    required this.hiveName,
    required this.isTeamCreator,
  });

  @override
  State<ProgressDetailScreen> createState() => _ProgressDetailScreenState();
}

class _ProgressDetailScreenState extends State<ProgressDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic> _performanceStats = {
    'totalTasks': 0,
    'completedTasks': 0,
    'inProgressTasks': 0,
    'todoTasks': 0,
    'completionRate': 0.0,
    'averageCompletionTime': 0.0,
    'overdueTasksCount': 0,
    'onTimeCompletionRate': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('hiveId', isEqualTo: widget.hiveId)
          .get();

      final tasks = tasksSnapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final completedAt = data['completedAt'];
        final dueDate = data['dueDate'];
        
        return {
          'id': doc.id,
          'title': data['title'],
          'description': data['description'],
          'status': data['status'],
          'createdAt': createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
          'completedAt': completedAt is Timestamp ? completedAt?.toDate() : null,
          'dueDate': dueDate is Timestamp ? dueDate.toDate() : null,
          'assignedTo': data['assignedTo'],
        };
      }).toList();

      // Sort tasks by creation date
      tasks.sort((a, b) {
        return (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime);
      });

      // Calculate performance statistics
      _calculatePerformanceStats(tasks);

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculatePerformanceStats(List<Map<String, dynamic>> tasks) {
    int totalTasks = tasks.length;
    int completedTasks = 0;
    int inProgressTasks = 0;
    int todoTasks = 0;
    int overdueTasksCount = 0;
    int onTimeCompletions = 0;
    int earlyCompletions = 0;
    int tasksWithDueDate = 0;
    
    List<Duration> completionTimes = [];
    
    for (var task in tasks) {
      switch (task['status']) {
        case 'done':
          completedTasks++;
          break;
        case 'inProgress':
          inProgressTasks++;
          break;
        case 'todo':
          todoTasks++;
          break;
      }
      
      // Check if the task has a due date
      if (task['dueDate'] != null) {
        final dueDate = task['dueDate'] as DateTime;
        tasksWithDueDate++;
        
        // Check if the task is overdue and not completed
        if (task['status'] != 'done' && dueDate.isBefore(DateTime.now())) {
          overdueTasksCount++;
        }
        
        // Calculate if completed on time or early
        if (task['status'] == 'done' && task['completedAt'] != null) {
          final completedAt = task['completedAt'] as DateTime;
          
          if (!completedAt.isAfter(dueDate)) {
            onTimeCompletions++;
            
            // Consider "early completion" if done at least 1 day before deadline
            final daysEarly = dueDate.difference(completedAt).inDays;
            if (daysEarly >= 1) {
              earlyCompletions++;
            }
          }
        }
      }
      
      // Calculate completion time for completed tasks
      if (task['status'] == 'done' && task['completedAt'] != null && task['createdAt'] != null) {
        final completedAt = task['completedAt'] as DateTime;
        final createdAt = task['createdAt'] as DateTime;
        completionTimes.add(completedAt.difference(createdAt));
      }
    }
    
    // Calculate average completion time
    double averageCompletionTime = 0;
    if (completionTimes.isNotEmpty) {
      final totalDays = completionTimes.fold<double>(
        0, 
        (sum, duration) => sum + duration.inHours / 24
      );
      averageCompletionTime = totalDays / completionTimes.length;
    }
    
    // Calculate completion rate
    double completionRate = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;
    
    // Calculate on-time completion rate
    double onTimeCompletionRate = completedTasks > 0 ? (onTimeCompletions / completedTasks) * 100 : 0;

    // Calculate performance rating (1-5 scale)
    double performanceRating = 3.0; // Default to middle rating
    
    if (totalTasks > 0) {
      // Start with a base rating of 3 stars
      performanceRating = 3.0;
      
      // No overdue tasks is a big positive
      if (overdueTasksCount == 0) {
        performanceRating += 1.0;
      } else {
        // Penalize for overdue tasks, but not below 1 star
        double overduePenalty = (overdueTasksCount / (tasksWithDueDate > 0 ? tasksWithDueDate : 1)) * 2.0;
        performanceRating -= overduePenalty;
      }
      
      // Early completions are a significant bonus
      if (tasksWithDueDate > 0) {
        double earlyBonus = (earlyCompletions / tasksWithDueDate) * 1.5;
        performanceRating += earlyBonus;
      }
      
      // High completion rate is a bonus
      if (completionRate >= 75) {
        performanceRating += 0.5;
      }
      
      // Clamp the rating between 1-5 stars
      performanceRating = performanceRating.clamp(1.0, 5.0);
    }
    
    // Calculate efficiency score (1-100)
    double efficiencyScore = 50.0; // Default to middle score
    
    if (totalTasks > 0) {
      // Base efficiency on several factors
      
      // Early completion is a major positive factor for efficiency
      double earlyFactor = tasksWithDueDate > 0 ? earlyCompletions / tasksWithDueDate : 0;
      
      // No overdue tasks indicates good efficiency
      double overdueFactor = tasksWithDueDate > 0 ? 1.0 - (overdueTasksCount / tasksWithDueDate) : 0;
      
      // High completion percentage also factors in
      double completionFactor = totalTasks > 0 ? completedTasks / totalTasks : 0;
      
      // Adjust for completion speed when available
      double speedFactor = 0.5; // Default middle value
      if (completionTimes.isNotEmpty) {
        // Lower times = higher efficiency
        speedFactor = 1.0 / (1 + averageCompletionTime / 5); // Normalized to favor less than a week
      }
      
      // Calculate weighted score - prioritize no overdue tasks and early completion
      efficiencyScore = (
        earlyFactor * 35 +        // 35% weight for early completions
        overdueFactor * 30 +      // 30% weight for having no overdue tasks
        completionFactor * 20 +   // 20% weight for high completion percentage
        speedFactor * 15          // 15% weight for speed of completion
      ) * 100;
      
      // Ensure within 1-100 range
      efficiencyScore = efficiencyScore.clamp(1.0, 100.0);
    }
    
    _performanceStats = {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'inProgressTasks': inProgressTasks,
      'todoTasks': todoTasks,
      'completionRate': completionRate,
      'averageCompletionTime': efficiencyScore,
      'overdueTasksCount': overdueTasksCount,
      'onTimeCompletionRate': performanceRating,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 48, bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.deepOrange.shade900
                    : Colors.orange.shade400,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black26
                        : Colors.orange.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[300]
                              : Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.hiveName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[300]
                                : Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.orange[700]!
                              : Colors.orange[600]!,
                        ),
                      ),
                    )
                  : _tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks found',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a task to get started',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[600]
                                      : Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 16, 
                            right: 16, 
                            top: 16, 
                            bottom: 40 // Increase bottom padding for the entire list
                          ),
                          itemCount: _tasks.length + 1, // +1 for statistics card
                          itemBuilder: (context, index) {
                            // Statistics card at the top
                            if (index == 0) {
                              return _buildStatisticsCard();
                            }
                            
                            // Tasks below with adjusted index
                            final taskIndex = index - 1;
                            final task = _tasks[taskIndex];
                            final isCompleted = task['status'] == 'done';
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[900]
                                  : Colors.white,
                              child: InkWell(
                                onTap: widget.isTeamCreator
                                    ? () {
                                        Navigator.pushNamed(
                                          context,
                                          '/task',
                                          arguments: task['id'],
                                        );
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.deepOrange[600]
                                                      : Colors.orange[400],
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${taskIndex + 1}',
                                                    style: TextStyle(
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.black
                                                          : Colors.black87,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(task['status'], context).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: _getStatusColor(task['status'], context).withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _getStatusIcon(task['status']),
                                                      size: 12,
                                                      color: _getStatusColor(task['status'], context),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _getStatusLabel(task['status']),
                                                      style: TextStyle(
                                                        color: _getStatusColor(task['status'], context),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  task['title'],
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: isCompleted
                                                        ? TextDecoration.lineThrough
                                                        : null,
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.grey[300]
                                                        : Colors.grey[800],
                                                  ),
                                                ),
                                              ),
                                              if (widget.isTeamCreator)
                                                Icon(
                                                  Icons.edit,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.grey[500]
                                                      : Colors.grey[400],
                                                  size: 16,
                                                ),
                                            ],
                                          ),
                                          if (task['description'] != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              task['description'],
                                              style: TextStyle(
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Created: ${DateFormat('MMM d, y').format(task['createdAt'])}',
                                                style: TextStyle(
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.grey[500]
                                                      : Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (task['dueDate'] != null)
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.event,
                                                      size: 12,
                                                      color: _isDueOrOverdue(task) 
                                                          ? Colors.red[400]
                                                          : Theme.of(context).brightness == Brightness.dark
                                                              ? Colors.grey[400]
                                                              : Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Due: ${DateFormat('MMM d, y').format(task['dueDate'])}',
                                                      style: TextStyle(
                                                        color: _isDueOrOverdue(task)
                                                            ? Colors.red[400]
                                                            : Theme.of(context).brightness == Brightness.dark
                                                                ? Colors.grey[400]
                                                                : Colors.grey[600],
                                                        fontSize: 12,
                                                        fontWeight: _isDueOrOverdue(task) ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          if (task['completedAt'] != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  size: 12,
                                                  color: Theme.of(context).brightness == Brightness.dark
                                                      ? Colors.green[400]
                                                      : Colors.green[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Completed: ${DateFormat('MMM d, y').format(task['completedAt'])}',
                                                  style: TextStyle(
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.green[400]
                                                        : Colors.green[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 'todo':
        return isDark ? Colors.orange[400]! : Colors.orange[600]!;
      case 'inProgress':
        return isDark ? Colors.blue[400]! : Colors.blue[600]!;
      case 'done':
        return isDark ? Colors.green[400]! : Colors.green[600]!;
      default:
        return isDark ? Colors.grey[400]! : Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'todo':
        return Icons.emoji_nature;
      case 'inProgress':
        return Icons.local_florist;
      case 'done':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'todo':
        return 'To Do';
      case 'inProgress':
        return 'In Progress';
      case 'done':
        return 'Done';
      default:
        return 'Unknown';
    }
  }

  bool _isDueOrOverdue(Map<String, dynamic> task) {
    if (task['dueDate'] == null || task['status'] == 'done') return false;
    
    final dueDate = task['dueDate'] as DateTime;
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    
    // Return true if due date is today or in the past
    return difference <= 0;
  }

  Widget _buildStatisticsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 24.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDark ? Colors.grey[850] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    size: 24,
                    color: isDark ? Colors.deepOrange[300] : Colors.orange[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Performance Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[200] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Task Status Distribution
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCounter(
                    'Total',
                    _performanceStats['totalTasks'].toString(),
                    Icons.assignment,
                    isDark ? Colors.grey[300]! : Colors.grey[700]!,
                  ),
                  _buildStatCounter(
                    'Done',
                    _performanceStats['completedTasks'].toString(),
                    Icons.check_circle,
                    isDark ? Colors.green[300]! : Colors.green[600]!,
                  ),
                  _buildStatCounter(
                    'In Progress',
                    _performanceStats['inProgressTasks'].toString(),
                    Icons.timelapse,
                    isDark ? Colors.blue[300]! : Colors.blue[600]!,
                  ),
                  _buildStatCounter(
                    'To Do',
                    _performanceStats['todoTasks'].toString(),
                    Icons.pending_actions,
                    isDark ? Colors.orange[300]! : Colors.orange[600]!,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              // Key Performance Indicators
              Row(
                children: [
                  Expanded(
                    child: _buildStatIndicator(
                      'Completion Rate',
                      '${_performanceStats['completionRate'].toStringAsFixed(1)}%',
                      Icons.sentiment_very_satisfied,
                      _getCompletionRateColor(_performanceStats['completionRate'], isDark),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatIndicator(
                      'On-Time Rate',
                      _performanceStats['onTimeCompletionRate'] >= 5.0 
                          ? '★★★★★' 
                          : _performanceStats['onTimeCompletionRate'] >= 4.5
                              ? '★★★★½'
                              : _performanceStats['onTimeCompletionRate'] >= 4.0
                                  ? '★★★★☆'
                                  : _performanceStats['onTimeCompletionRate'] >= 3.5
                                      ? '★★★½☆'
                                      : _performanceStats['onTimeCompletionRate'] >= 3.0
                                          ? '★★★☆☆'
                                          : _performanceStats['onTimeCompletionRate'] >= 2.5
                                              ? '★★½☆☆'
                                              : _performanceStats['onTimeCompletionRate'] >= 2.0
                                                  ? '★★☆☆☆'
                                                  : _performanceStats['onTimeCompletionRate'] >= 1.5
                                                      ? '★½☆☆☆'
                                                      : _performanceStats['onTimeCompletionRate'] >= 1.0
                                                          ? '★☆☆☆☆'
                                                          : '☆☆☆☆☆',
                      _getOnTimeRateIcon(_performanceStats['onTimeCompletionRate']),
                      _getOnTimeRateColor(_performanceStats['onTimeCompletionRate'], isDark),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatIndicator(
                      'Avg. Completion',
                      '${_performanceStats['averageCompletionTime'].toStringAsFixed(0)}/100',
                      Icons.speed,
                      isDark ? Colors.blue[300]! : Colors.blue[600]!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatIndicator(
                      'Overdue',
                      _performanceStats['overdueTasksCount'].toString(),
                      Icons.warning_amber,
                      _performanceStats['overdueTasksCount'] > 0 
                          ? (isDark ? Colors.red[300]! : Colors.red[600]!)
                          : (isDark ? Colors.green[300]! : Colors.green[600]!),
                      containerColor: _performanceStats['overdueTasksCount'] > 0 
                          ? (isDark ? Colors.red.withOpacity(0.15) : Colors.red.withOpacity(0.1))
                          : null,
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
  
  Widget _buildStatCounter(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatIndicator(String label, String value, IconData icon, Color color, {Color? containerColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: _getTooltipText(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: containerColor ?? color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _getShortLabel(label),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getShortLabel(String label) {
    switch (label) {
      case 'Completion Rate': return 'Completed Tasks';
      case 'On-Time Rate': return 'Performance Rating';
      case 'Avg. Completion': return 'Efficiency Score';
      default: return label;
    }
  }
  
  IconData _getCompletionRateIcon(double rate) {
    if (rate >= 75) return Icons.sentiment_very_satisfied;
    if (rate >= 50) return Icons.sentiment_satisfied;
    if (rate >= 25) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }
  
  Color _getCompletionRateColor(double rate, bool isDark) {
    if (rate >= 75) return isDark ? Colors.green[300]! : Colors.green[600]!;
    if (rate >= 50) return isDark ? Colors.lime[300]! : Colors.lime[600]!;
    if (rate >= 25) return isDark ? Colors.amber[300]! : Colors.amber[600]!;
    return isDark ? Colors.red[300]! : Colors.red[600]!;
  }
  
  IconData _getOnTimeRateIcon(double rate) {
    if (rate >= 4.5) return Icons.stars;
    if (rate >= 3.5) return Icons.star_rate;
    if (rate >= 2.5) return Icons.star_half;
    if (rate >= 1.5) return Icons.star_outline;
    return Icons.star_border;
  }
  
  Color _getOnTimeRateColor(double rate, bool isDark) {
    if (rate >= 4.0) return isDark ? Colors.green[300]! : Colors.green[600]!;
    if (rate >= 3.0) return isDark ? Colors.lime[300]! : Colors.lime[600]!;
    if (rate >= 2.0) return isDark ? Colors.amber[300]! : Colors.amber[600]!;
    return isDark ? Colors.red[300]! : Colors.red[600]!;
  }

  String _getTooltipText(String label) {
    switch (label) {
      case 'Completion Rate': 
        return 'Percentage of total tasks that have been completed';
      case 'On-Time Rate': 
        return 'Performance rating (1-5 stars) based on meeting deadlines, with bonus for early completion';
      case 'Avg. Completion': 
        return 'Efficiency score based on task completion speed and resource utilization';
      case 'Overdue': 
        return 'Number of tasks past their due date that are not yet complete';
      default: 
        return label;
    }
  }
} 