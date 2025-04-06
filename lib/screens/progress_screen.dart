import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/main.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/utils/navigation_utils.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _hives = [];
  bool _isTeamCreator = false;
  Map<String, dynamic> _teamStats = {
    'totalTasks': 0,
    'completedTasks': 0,
    'inProgressTasks': 0,
    'overdueTasks': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadHives();
  }

  Future<void> _loadHives() async {
    setState(() => _isLoading = true);
    try {
      // Get current team ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      final currentTeamId = userDoc.data()?['currentTeamId'];
      
      if (currentTeamId != null) {
        // Check if user is team creator
        final teamDoc = await FirebaseFirestore.instance
            .collection('teams')
            .doc(currentTeamId)
            .get();
        
        setState(() {
          _isTeamCreator = teamDoc.data()?['createdBy'] == currentUserId;
        });

        // Get all hives for the team
        final hivesSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .where('teamId', isEqualTo: currentTeamId)
            .get();

        int totalTeamTasks = 0;
        int completedTeamTasks = 0;
        int inProgressTeamTasks = 0;
        int overdueTeamTasks = 0;

        // For each hive, get its tasks and calculate progress
        final hives = await Future.wait(
          hivesSnapshot.docs.map((doc) async {
            final tasksSnapshot = await FirebaseFirestore.instance
                .collection('tasks')
                .where('hiveId', isEqualTo: doc.id)
                .get();

            final tasks = tasksSnapshot.docs;
            final now = DateTime.now();

            final totalTasks = tasks.length;
            final completedTasks = tasks
                .where((task) => task.data()['status'] == 'done')
                .length;
            final inProgressTasks = tasks
                .where((task) => task.data()['status'] == 'inProgress')
                .length;
            final overdueTasks = tasks
                .where((task) {
                  final dueDate = (task.data()['dueDate'] as Timestamp?)?.toDate();
                  return dueDate != null && 
                         dueDate.isBefore(now) && 
                         task.data()['status'] != 'done';
                })
                .length;

            totalTeamTasks += totalTasks;
            completedTeamTasks += completedTasks;
            inProgressTeamTasks += inProgressTasks;
            overdueTeamTasks += overdueTasks;

            final lastActivity = tasks.isEmpty ? null : tasks
                .map((t) => (t.data()['updatedAt'] as Timestamp).toDate())
                .reduce((a, b) => a.isAfter(b) ? a : b);

            return {
              'id': doc.id,
              'name': doc.data()['name'],
              'description': doc.data()['description'],
              'totalTasks': totalTasks,
              'completedTasks': completedTasks,
              'inProgressTasks': inProgressTasks,
              'overdueTasks': overdueTasks,
              'progress': totalTasks > 0 ? completedTasks / totalTasks : 0.0,
              'lastActivity': lastActivity,
            };
          }),
        );

        setState(() {
          _hives = hives;
          _teamStats = {
            'totalTasks': totalTeamTasks,
            'completedTasks': completedTeamTasks,
            'inProgressTasks': inProgressTeamTasks,
            'overdueTasks': overdueTeamTasks,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading hives: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTeamStats() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Tasks',
                    _teamStats['totalTasks'].toString(),
                    Icons.task,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Completed',
                    _teamStats['completedTasks'].toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'In Progress',
                    _teamStats['inProgressTasks'].toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Overdue',
                    _teamStats['overdueTasks'].toString(),
                    Icons.warning,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackNavigationHandler.wrapWithPopScope(
      onBackPress: () {
        // Return to home tab when back is pressed
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          return true;
        }
        return false;
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadHives,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildTeamStats(),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Hives Progress',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.pushNamed(context, '/all-hives');
                              },
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _hives.isEmpty
                        ? SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.hive,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hives found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create a new hive to start tracking progress',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final hive = _hives[index];
                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/progress-detail',
                                          arguments: {
                                            'hiveId': hive['id'],
                                            'hiveName': hive['name'],
                                            'isTeamCreator': _isTeamCreator,
                                          },
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
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
                                                    color: Colors.orange.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    Icons.hive,
                                                    color: Colors.orange[700],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        hive['name'],
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      if (hive['description'] != null && hive['description'].isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          hive['description'],
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
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: LinearProgressIndicator(
                                                      value: hive['progress'],
                                                      minHeight: 8,
                                                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.grey[800]
                                                          : Colors.grey[200],
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Theme.of(context).brightness == Brightness.dark
                                                            ? Colors.deepOrange.shade300
                                                            : Colors.amber.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text(
                                                  '${(hive['progress'] * 100).round()}%',
                                                  style: TextStyle(
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.deepOrange.shade300
                                                        : Colors.amber.shade700,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${hive['completedTasks']} of ${hive['totalTasks']} tasks completed',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (hive['lastActivity'] != null)
                                                  Text(
                                                    'Last activity: ${DateFormat('MMM d').format(hive['lastActivity'])}',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: _hives.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }
} 