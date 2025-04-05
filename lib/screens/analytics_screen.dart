import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/main.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? _teamId;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      final teamId = userDoc.data()?['teamId'];
      if (teamId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get team tasks
      final tasksQuery = await FirebaseFirestore.instance
          .collection('tasks')
          .where('teamId', isEqualTo: teamId)
          .get();

      // Calculate statistics
      int totalTasks = tasksQuery.docs.length;
      int completedTasks = tasksQuery.docs
          .where((doc) => doc.data()['status'] == 'done')
          .length;
      int inProgressTasks = tasksQuery.docs
          .where((doc) => doc.data()['status'] == 'in_progress')
          .length;
      int pendingTasks = totalTasks - completedTasks - inProgressTasks;

      // Get projects (hives)
      final projectsQuery = await FirebaseFirestore.instance
          .collection('projects')
          .where('teamId', isEqualTo: teamId)
          .get();

      setState(() {
        _teamId = teamId;
        _stats = {
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'inProgressTasks': inProgressTasks,
          'pendingTasks': pendingTasks,
          'totalProjects': projectsQuery.docs.length,
          'completionRate': totalTasks > 0
              ? (completedTasks / totalTasks * 100).toStringAsFixed(1)
              : '0.0',
        };
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamId == null) {
      return const Center(
        child: Text('Please join a team to view analytics'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Tasks',
                  _stats['totalTasks'].toString(),
                  Icons.task,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Projects',
                  _stats['totalProjects'].toString(),
                  Icons.folder,
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Completion Rate',
                  '${_stats['completionRate']}%',
                  Icons.pie_chart,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'In Progress',
                  _stats['inProgressTasks'].toString(),
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Task Status Chart
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Status Distribution',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: _stats['completedTasks'].toDouble(),
                            title: 'Done',
                            color: Colors.green,
                            radius: 80,
                          ),
                          PieChartSectionData(
                            value: _stats['inProgressTasks'].toDouble(),
                            title: 'In Progress',
                            color: Colors.orange,
                            radius: 80,
                          ),
                          PieChartSectionData(
                            value: _stats['pendingTasks'].toDouble(),
                            title: 'Pending',
                            color: Colors.grey,
                            radius: 80,
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Task Status Legend
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Status Breakdown',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildLegendItem(
                    'Completed Tasks',
                    _stats['completedTasks'].toString(),
                    Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    'In Progress Tasks',
                    _stats['inProgressTasks'].toString(),
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    'Pending Tasks',
                    _stats['pendingTasks'].toString(),
                    Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
} 