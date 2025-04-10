import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/models/hive_project.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/screens/hive_detail_screen.dart';
import 'package:taskhive/screens/bee_detail_screen.dart';
import 'package:taskhive/screens/calendar_screen.dart';
import 'package:taskhive/screens/focus_screen.dart';
import 'package:taskhive/screens/profile_screen.dart';
import 'package:taskhive/screens/team_management_screen.dart';
import 'package:taskhive/screens/all_hives_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taskhive/screens/progress_screen.dart';
import 'package:clipboard/clipboard.dart';
import 'dart:async';
import 'package:taskhive/screens/notification_list_screen.dart';
import 'package:taskhive/utils/navigation_utils.dart';
import 'package:taskhive/screens/chat_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskhive/screens/tutorial_screen.dart';
import 'package:taskhive/screens/about_screen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:taskhive/screens/upcoming_tasks_page.dart';
import 'package:taskhive/screens/team_info_page.dart';

class DashboardScreen extends StatefulWidget {
  final String? teamId;
  const DashboardScreen({super.key, this.teamId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  List<HiveProject> _projects = [];
  List<BeeTask> _tasks = [];
  Map<String, List<BeeTask>> _tasksByHive = {};
  String? _currentTeamId;
  bool _isTeamCreator = false;
  int _inAppNotificationCount = 0;
  late Timer _refreshTimer;
  // Track back button presses for exit
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    if (widget.teamId != null) {
      _currentTeamId = widget.teamId;
      _loadData();
    } else {
      _loadTeamData();
    }
    
    // Check for unread notifications
    _checkUnreadNotifications();
    
    // Set up a periodic refresh timer
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _loadData(isBackground: true);
      _checkUnreadNotifications();
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get team ID from route arguments if available
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args != _currentTeamId) {
      setState(() {
        _currentTeamId = args;
      });
      _loadData();
    }
    
    // Always refresh notification count when returning to dashboard
    _checkUnreadNotifications();
  }

  Future<void> _loadTeamData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      final currentTeamId = userDoc.data()?['currentTeamId'];
      
      if (currentTeamId != null) {
        final teamDoc = await FirebaseFirestore.instance
            .collection('teams')
            .doc(currentTeamId)
            .get();
        
        setState(() {
          _currentTeamId = currentTeamId;
          _isTeamCreator = teamDoc.data()?['createdBy'] == currentUserId;
        });
      }
    } catch (e) {
      print('Error loading team data: $e');
    }
  }

  Future<void> _loadData({bool isBackground = false}) async {
    print('Loading data with current team ID: $_currentTeamId'); // Debug print
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        _currentTeamId = userDoc.data()?['currentTeamId'];
      });

      if (_currentTeamId != null) {
        final teamDoc = await FirebaseFirestore.instance
            .collection('teams')
            .doc(_currentTeamId)
            .get();

        if (teamDoc.exists) {
          setState(() {
            _isTeamCreator = teamDoc.data()?['createdBy'] == user.uid;
          });
        }
      }

      // If no team is selected, show empty state
      if (_currentTeamId == null) {
        print('No team selected, showing empty state'); // Debug print
        setState(() {
          _projects = [];
          _tasks = [];
          _tasksByHive = {};
          _isLoading = false;
        });
        return;
      }

      // Load projects (hives) for current team only
      print('Loading projects for team: $_currentTeamId'); // Debug print
      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('teamId', isEqualTo: _currentTeamId)
          .get();
      
      final projects = projectsSnapshot.docs
          .map((doc) => HiveProject.fromFirestore(doc))
          .toList();
      
      print('Found ${projects.length} projects'); // Debug print

      // Load tasks for current team only
      print('Loading tasks for team: $_currentTeamId'); // Debug print
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('teamId', isEqualTo: _currentTeamId)
          .where('status', whereIn: ['todo', 'inProgress'])
          .get();
      
      final tasks = tasksSnapshot.docs
          .map((doc) => BeeTask.fromFirestore(doc))
          .toList();
      
      print('Found ${tasks.length} tasks'); // Debug print

      // Group tasks by hive
      final tasksByHive = <String, List<BeeTask>>{};
      for (final task in tasks) {
        final hiveId = task.hiveId;
        if (hiveId.isNotEmpty) {  // Only add tasks that have a hive
          if (!tasksByHive.containsKey(hiveId)) {
            tasksByHive[hiveId] = [];
          }
          tasksByHive[hiveId]!.add(task);
        }
      }
      
      setState(() {
        _projects = projects;
        _tasks = tasks;
        _tasksByHive = tasksByHive;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e'); // Debug print
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboard(),
      const ChatHubScreen(),
      const ProgressScreen(),
      const CalendarScreen(),
      const FocusScreen(),
    ];

    return WillPopScope(
      onWillPop: () async {
        // If not on the Home screen, go to home first
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0; // Switch to home tab
          });
          return false; // Prevent app exit
        }
        
        // If already on Home screen, implement double-back to exit behavior
        final now = DateTime.now();
        if (_lastBackPressTime == null || 
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true; // Allow app exit on second press
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(
                Icons.hive,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.amber.shade300
                    : Colors.amber.shade700,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text('TaskHive'),
            ],
          ),
          actions: [
            // Notification bell with counter
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/notifications');
                    _checkUnreadNotifications(); // Refresh count when returning
                  },
                ),
                if (_inAppNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _inAppNotificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : screens[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      const Color(0xFF1E1E1E),
                      Colors.black.withOpacity(0.9),
                    ]
                  : [
                      Colors.white,
                      Colors.grey.shade50,
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black26
                    : Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            height: 65,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: const Duration(milliseconds: 400),
            destinations: [
              _buildNavDestination(
                context,
                Icons.home_outlined,
                Icons.home,
                'Home',
                0,
              ),
              _buildNavDestination(
                context,
                Icons.chat_outlined,
                Icons.chat,
                'Chat',
                1,
              ),
              _buildNavDestination(
                context,
                Icons.analytics_outlined,
                Icons.analytics,
                'Progress',
                2,
              ),
              _buildNavDestination(
                context,
                Icons.calendar_month_outlined,
                Icons.calendar_month,
                'Calendar',
                3,
              ),
              _buildNavDestination(
                context,
                Icons.timer_outlined,
                Icons.timer,
                'Focus',
                4,
              ),
            ],
          ),
        ),
        floatingActionButton: _selectedIndex == 0 && _isTeamCreator
            ? FloatingActionButton(
                onPressed: _showCreateProjectDialog,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                tooltip: 'Create Hive',
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 24),
            _buildProjectsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    // Get current user's name
    final currentUser = FirebaseAuth.instance.currentUser;
    final userName = currentUser?.displayName ?? 'User';
    
    // Get user's name from Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get(),
      builder: (context, snapshot) {
        // Get name from Firestore or fallback to display name
        String name = 'User';
        if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          name = userData?['name'] ?? currentUser?.displayName ?? 'User';
        }
        
        // Get current date
        final now = DateTime.now();
        final dateStr = DateFormat('EEEE, MMMM d').format(now);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hello User and Date
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $name!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatsSection() {
    // Filter tasks assigned to current user and sort by due date
    final upcomingTasks = _tasks
        .where((task) => task.assignedTo == currentUserId)
        .where((task) => task.dueDate != null)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Active Hives',
                  _projects.length.toString(),
                  Icons.hive,
                  Colors.amber,
                ),
                _buildStatCard(
                  'Busy Bees',
                  _tasks.where((t) => t.status == BeeStatus.inProgress).length.toString(),
                  Icons.local_florist,
                  Colors.green,
                ),
                _buildStatCard(
                  'To Do',
                  _tasks.where((t) => t.status == BeeStatus.todo).length.toString(),
                  Icons.emoji_nature,
                  Colors.orange,
                ),
              ],
            ),
            if (upcomingTasks.isNotEmpty) ...[
              const Divider(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Tasks',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showUpcomingTasksPage(upcomingTasks),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: upcomingTasks.length > 3 ? 3 : upcomingTasks.length,
                    itemBuilder: (context, index) {
                      final task = upcomingTasks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
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
                        title: Text(
                          task.title,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          DateFormat('MMM d, y').format(task.dueDate!),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BeeDetailScreen(taskId: task.id),
                            ),
                          ).then((_) => _loadData());
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 28,
          ),
        ),
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
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTasksSection() {
    final upcomingTasks = _tasks
        .where((task) => task.assignedTo == currentUserId)
        .where((task) => task.status != BeeStatus.done)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => SizedBox(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: UpcomingTasksPage(
                          tasks: _tasks,
                          onTaskUpdated: _loadData,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (upcomingTasks.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No upcoming tasks',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: upcomingTasks.take(3).map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
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
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (task.dueDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, y').format(task.dueDate!),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _showUpcomingTasksPage(List<BeeTask> tasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => UpcomingTasksPage(
          tasks: tasks,
          onTaskUpdated: _loadData,
        ),
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hive,
                  color: Colors.amber[700],
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Your Hives',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllHivesScreen(teamId: _currentTeamId!),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.remove_red_eye),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _projects.isEmpty
            ? _buildEmptyState(
                'No hives yet',
                'Create a new hive to get started',
                Icons.hive,
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final project = _projects[index];
                  final hiveTasks = _tasksByHive[project.id] ?? [];
                  return _buildProjectCard(project, hiveTasks);
                },
              ),
      ],
    );
  }

  Widget _buildProjectCard(HiveProject project, List<BeeTask> tasks) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/project',
            arguments: project.id,
          ).then((_) => _loadData());
        },
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
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.hive,
                      color: Colors.amber[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (project.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            project.description,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_nature,
                          size: 16,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tasks.length}',
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (tasks.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTaskCard(task);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(BeeTask task) {
    final isAssignedToCurrentUser = task.assignedTo == currentUserId;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isAssignedToCurrentUser 
          ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.deepOrange.shade900.withOpacity(0.2)
              : Colors.orange.shade50)
          : null,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BeeDetailScreen(taskId: task.id),
            ),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isAssignedToCurrentUser ? FontWeight.bold : FontWeight.normal,
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
                  const SizedBox(width: 8),
                  if (isAssignedToCurrentUser)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.deepOrange.shade900.withOpacity(0.3)
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.deepOrange.shade300
                                : Colors.orange.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Your Task',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.deepOrange.shade300
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildStatusChip(task.status),
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
                              Icons.person,
                              size: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userName,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 12,
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
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, y').format(task.dueDate!),
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
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

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaskStatus(BeeTask task) async {
    try {
      final newStatus = task.status == BeeStatus.inProgress
          ? BeeStatus.todo
          : BeeStatus.inProgress;

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
            content: Text(
              newStatus == BeeStatus.inProgress
                  ? 'Task marked as In Progress'
                  : 'Task marked as To Do'
            ),
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
              title: const Text('Toggle Status'),
              subtitle: Text(
                task.status == BeeStatus.inProgress
                    ? 'Mark as To Do'
                    : 'Mark as In Progress'
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleTaskStatus(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Mark as Done'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('tasks')
                      .doc(task.id)
                      .update({
                    'status': BeeStatus.done.toString().split('.').last,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task marked as done')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating task: ${e.toString()}')),
                    );
                  }
                }
              },
            ),
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
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    print('Current Team ID when creating hive: $_currentTeamId'); // Debug print

    // Check if team is selected
    if (_currentTeamId == null || _currentTeamId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a team first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Hive'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
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
                  const SnackBar(content: Text('Please enter a project name')),
                );
                return;
              }

              // Double check team ID is still available and valid
              if (_currentTeamId == null || _currentTeamId!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No team selected. Please select a team first.')),
                );
                return;
              }
              
              try {
                print('Creating hive with team ID: $_currentTeamId'); // Debug print
                
                // Verify the team exists before creating the hive
                final teamDoc = await FirebaseFirestore.instance
                    .collection('teams')
                    .doc(_currentTeamId)
                    .get();
                
                if (!teamDoc.exists) {
                  throw Exception('Selected team does not exist');
                }
                
                final projectDoc = await FirebaseFirestore.instance
                    .collection('projects')
                    .add({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'status': 'planning',
                  'createdBy': currentUserId,
                  'teamId': _currentTeamId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'memberCount': 1,
                });

                print('Created hive with ID: ${projectDoc.id}'); // Debug print
                
                if (mounted) {
                  Navigator.pop(context);
                  await _loadData();  // Reload data to show new hive
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hive created successfully')),
                  );
                }
              } catch (e) {
                print('Error creating hive: $e'); // Debug print
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating hive: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
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

  Widget _buildPriorityChip(BeePriority priority) {
    Color color;
    String label;

    switch (priority) {
      case BeePriority.worker:
        color = Colors.blue;
        label = 'Worker';
        break;
      case BeePriority.warrior:
        color = Colors.orange;
        label = 'Warrior';
        break;
      case BeePriority.queen:
        color = Colors.red;
        label = 'Queen';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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

  void _showTeamCodeDialog() async {
    if (_currentTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please join a team first')),
      );
      return;
    }

    try {
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(_currentTeamId)
          .get();

      if (!mounted) return;

      final theme = Theme.of(context);
      final inviteCode = teamDoc.data()?['inviteCode'];

      if (inviteCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team code not found')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Team Invite Code',
            style: theme.textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share this code with your team members:',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surfaceVariant
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.primary.withOpacity(0.5)
                        : Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        inviteCode,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.onSurface
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        // Copy invite code to clipboard
                        FlutterClipboard.copy(inviteCode).then((value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Team code copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading team code: ${e.toString()}')),
      );
    }
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

  Widget _buildTeamMembersSection() {
    if (_currentTeamId == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.group,
              color: Colors.amber[700],
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'Team Members',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teams')
              .doc(_currentTeamId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final teamData = snapshot.data?.data() as Map<String, dynamic>?;
            if (teamData == null) {
              return const Center(
                child: Text('Team not found'),
              );
            }

            final creatorId = teamData['createdBy'] as String?;
            final members = List<String>.from(teamData['members'] ?? []);

            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait(
                members.map((id) => FirebaseFirestore.instance
                    .collection('users')
                    .doc(id)
                    .get()),
              ),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final users = userSnapshot.data ?? [];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_alt,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${users.length} Members',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final userData = user.data() as Map<String, dynamic>?;
                          final isCreator = user.id == creatorId;
                          final isCurrentUser = user.id == currentUserId;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCreator 
                                  ? Colors.amber.shade100 
                                  : Colors.grey.shade100,
                              child: Icon(
                                Icons.person,
                                color: isCreator 
                                    ? Colors.amber[700]
                                    : Colors.grey[700],
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userData?['name'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isCurrentUser)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'You',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              isCreator ? 'Admin' : 'Member',
                              style: TextStyle(
                                color: isCreator ? Colors.amber[700] : Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _showDisbandTeamDialog() async {
    final disbandController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disband Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action cannot be undone. All hives and tasks will be deleted.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type DISBAND to confirm:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: disbandController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
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
              if (disbandController.text != 'DISBAND') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please type DISBAND to confirm')),
                );
                return;
              }

              try {
                // Get all hives in the team
                final hivesSnapshot = await FirebaseFirestore.instance
                    .collection('projects')
                    .where('teamId', isEqualTo: _currentTeamId)
                    .get();

                // Get all tasks in the team
                final tasksSnapshot = await FirebaseFirestore.instance
                    .collection('tasks')
                    .where('teamId', isEqualTo: _currentTeamId)
                    .get();

                // Get the team document
                final teamDoc = await FirebaseFirestore.instance
                    .collection('teams')
                    .doc(_currentTeamId)
                    .get();

                if (!teamDoc.exists) {
                  throw Exception('Team not found');
                }

                // Start a batch write
                final batch = FirebaseFirestore.instance.batch();

                // Delete all hives
                for (final doc in hivesSnapshot.docs) {
                  batch.delete(doc.reference);
                }

                // Delete all tasks
                for (final doc in tasksSnapshot.docs) {
                  batch.delete(doc.reference);
                }

                // Update all team members to remove this team
                final teamData = teamDoc.data();
                if (teamData != null && teamData['members'] is List) {
                  final members = List<String>.from(teamData['members']);
                  for (final memberId in members) {
                    final userRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(memberId);
                    
                    batch.update(userRef, {
                      'currentTeamId': FieldValue.delete(),
                      'teams': FieldValue.arrayRemove([_currentTeamId]),
                    });
                  }
                }

                // Delete the team
                batch.delete(teamDoc.reference);

                // Commit the batch
                await batch.commit();

                if (mounted) {
                  // Close the dialog
                  Navigator.pop(context);
                  
                  // Navigate to team management screen
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/team',
                    (route) => false,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team disbanded successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error disbanding team: ${e.toString()}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Disband Team'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavDestination(
    BuildContext context,
    IconData outlinedIcon,
    IconData filledIcon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    final color = Theme.of(context).brightness == Brightness.dark
        ? isSelected
            ? Colors.deepOrange.shade300
            : Colors.grey.shade400
        : isSelected
            ? Colors.amber.shade700
            : Colors.grey.shade600;

    return NavigationDestination(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isSelected ? filledIcon : outlinedIcon,
          color: color,
          key: ValueKey(isSelected),
        ),
      ),
      label: label,
    );
  }

  // Add back the notification check method with debug statements removed
  Future<void> _checkUnreadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();
      
      setState(() {
        _inAppNotificationCount = notificationsSnapshot.docs.length;
      });
    } catch (e) {
      // Error handling
    }
  }

  // Add new drawer method with profile functions
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .get(),
            builder: (context, snapshot) {
              // User info for the drawer header
              String name = 'Loading...';
              String email = '';
              String role = 'Member';
              
              if (snapshot.hasData && snapshot.data != null) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                name = userData?['name'] ?? 'Unknown User';
                email = FirebaseAuth.instance.currentUser?.email ?? '';
                role = userData?['role'] ?? 'Member';
              }
              
              return UserAccountsDrawerHeader(
                accountName: Text(name),
                accountEmail: Text(email),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.deepOrange.shade900
                      : Colors.orange.shade400,
                ),
              );
            }
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              _showEditProfileDialog();
            },
          ),
          
          // Team section
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: Text('TEAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Team Info'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeamInfoPage(),
                ),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Switch Team'),
            onTap: () async {
              Navigator.pop(context); // Close drawer
              final result = await Navigator.pushNamed(
                context,
                '/team',
              );
              if (result != null && result is String) {
                setState(() {
                  _currentTeamId = result;
                });
                await _loadData();
              }
            },
          ),
          
          if (_currentTeamId != null && _isTeamCreator)
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Team Code'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showTeamCodeDialog();
              },
            ),
            
          if (_currentTeamId != null && _isTeamCreator)
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Disband Team'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showDisbandTeamDialog();
              },
            ),
          
          // Settings Section
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            trailing: FutureBuilder<SharedPreferences>(
              future: SharedPreferences.getInstance(),
              builder: (context, snapshot) {
                bool isDarkMode = false;
                if (snapshot.hasData) {
                  isDarkMode = snapshot.data!.getBool('isDarkMode') ?? false;
                }
                
                return Switch(
                  value: isDarkMode,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isDarkMode', value);
                    
                    final appState = TaskHiveApp.of(context);
                    if (appState != null) {
                      appState.toggleTheme(value);
                    }
                    
                    setState(() {}); // Update UI
                  },
                  activeColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.deepOrange.shade300
                      : Colors.orange.shade700,
                );
              },
            ),
            onTap: () {
              // The switch handles the action
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('App Tutorial'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TutorialScreen()),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              _showChangePasswordDialog();
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About TaskHive'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: ${e.toString()}')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // Add edit profile dialog method
  void _showEditProfileDialog() {
    final nameController = TextEditingController();
    
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get()
        .then((doc) {
      if (doc.exists) {
        nameController.text = doc.data()?['name'] ?? '';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Profile'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username cannot be empty')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .update({
                    'name': nameController.text.trim(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully')),
                    );
                    setState(() {});  // Refresh UI
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating profile: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    });
  }

  // Add change password dialog method
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureCurrentPassword = !obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
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
                if (currentPasswordController.text.isEmpty ||
                    newPasswordController.text.isEmpty ||
                    confirmPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match')),
                  );
                  return;
                }

                try {
                  // Get user credentials for reauthentication
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final email = user.email;
                  if (email == null) {
                    throw Exception('User email not found');
                  }

                  // Reauthenticate
                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: currentPasswordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);

                  // Update password
                  await user.updatePassword(newPasswordController.text);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
} 