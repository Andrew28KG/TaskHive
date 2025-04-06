import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/models/event.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/screens/bee_detail_screen.dart';
import 'package:taskhive/screens/event_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final String? teamId;
  const CalendarScreen({super.key, this.teamId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool _isLoading = true;
  List<BeeTask> _allTasks = [];
  List<Event> _allEvents = [];
  String? _currentTeamId;
  bool _isTeamCreator = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _currentTeamId = widget.teamId;
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadTasks();
    await _loadEvents();
    await _checkTeamCreator();
  }

  Future<void> _checkTeamCreator() async {
    try {
      if (_currentTeamId == null || currentUserId == null) {
        setState(() => _isTeamCreator = false);
        return;
      }

      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(_currentTeamId)
          .get();

      if (!teamDoc.exists) {
        setState(() => _isTeamCreator = false);
        return;
      }

      final data = teamDoc.data() as Map<String, dynamic>;
      setState(() {
        _isTeamCreator = data['createdBy'] == currentUserId;
      });
    } catch (e) {
      print('Error checking team creator: $e');
      setState(() => _isTeamCreator = false);
    }
  }

  Future<void> _loadEvents() async {
    try {
      // If no team is selected, show empty state
      if (_currentTeamId == null) {
        setState(() {
          _allEvents = [];
          _updateEventsMap();
        });
        return;
      }

      // Load events for current team
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('teamId', isEqualTo: _currentTeamId)
          .get();

      _allEvents = eventsSnapshot.docs
          .map((doc) => Event.fromFirestore(doc))
          .toList();

      _updateEventsMap();
    } catch (e) {
      print('Error loading events: $e');
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      // Get current team ID from user document if not set
      if (_currentTeamId == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        _currentTeamId = userDoc.data()?['currentTeamId'];
      }

      // If no team is selected, show empty state
      if (_currentTeamId == null) {
        setState(() {
          _allTasks = [];
          _events = {};
          _isLoading = false;
        });
        return;
      }

      // Load tasks for current team
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('teamId', isEqualTo: _currentTeamId)
          .where('status', whereIn: ['todo', 'inProgress'])
          .get();

      _allTasks = tasksSnapshot.docs
          .map((doc) => BeeTask.fromFirestore(doc))
          .toList();

      _updateEventsMap();
    } catch (e) {
      print('Error loading tasks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateEventsMap() {
    final Map<DateTime, List<dynamic>> newEvents = {};
    
    // Add tasks to events map
    for (final task in _allTasks) {
      if (task.dueDate != null) {
        final date = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );

        if (newEvents[date] == null) {
          newEvents[date] = [];
        }
        newEvents[date]!.add(task);
      }
    }
    
    // Add events to events map
    for (final event in _allEvents) {
      final date = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );

      if (newEvents[date] == null) {
        newEvents[date] = [];
      }
      newEvents[date]!.add(event);
    }

    setState(() {
      _events = newEvents;
    });
  }

  List<dynamic> _getItemsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _getItemsForDay(day);
  }

  List<BeeTask> _getTasksForDay(DateTime day) {
    return _getItemsForDay(day).whereType<BeeTask>().toList();
  }
  
  List<BeeTask> _getTaskEventsForCalendar(DateTime day) {
    // For the calendar widget, we need to return BeeTask objects
    // This is a workaround for the TableCalendar type constraint
    final items = _getItemsForDay(day);
    
    // For the marker dots, we only need to know there are items
    // We'll use BeeTask objects as a placeholder for events too
    if (items.isNotEmpty) {
      final tasks = items.whereType<BeeTask>().toList();
      
      // If there are tasks, return them
      if (tasks.isNotEmpty) {
        return tasks;
      }
      
      // If there are only events but no tasks, return a placeholder BeeTask
      // just to show a marker dot on the calendar
      if (items.any((item) => item is Event)) {
        // Create a dummy task just to show the marker
        // This won't be displayed anywhere, just used for the calendar dots
        return [
          BeeTask(
            id: 'event-marker',
            hiveId: '',
            title: 'Event Marker',
            description: '',
            assignedTo: '',
            createdAt: DateTime.now(),
            teamId: '',
          )
        ];
      }
    }
    
    return [];
  }
  
  List<Event> _getCalendarEventsForDay(DateTime day) {
    return _getItemsForDay(day).whereType<Event>().toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Calendar Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.deepOrange.shade900
                    : Colors.orange.shade400,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black26
                        : Colors.orange.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Calendar',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Calendar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Theme.of(context).brightness == Brightness.dark
                  ? TableCalendar<BeeTask>(
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      calendarFormat: CalendarFormat.month,
                      eventLoader: _getTaskEventsForCalendar,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      rowHeight: 52,
                      daysOfWeekHeight: 32,
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: Colors.deepOrange.shade400,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.deepOrange.shade200.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: Colors.deepOrange.shade300,
                          shape: BoxShape.circle,
                        ),
                        weekendTextStyle: TextStyle(
                          color: Colors.grey[400],
                        ),
                        holidayTextStyle: TextStyle(
                          color: Colors.grey[400],
                        ),
                        markersMaxCount: 3,
                        markerSize: 5,
                        markersAlignment: Alignment.bottomCenter,
                        markerMargin: const EdgeInsets.only(top: 6),
                        todayTextStyle: TextStyle(
                          color: Colors.deepOrange.shade200,
                          fontWeight: FontWeight.bold,
                        ),
                        cellMargin: const EdgeInsets.all(4),
                        cellPadding: EdgeInsets.zero,
                        outsideTextStyle: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[200],
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Colors.grey[400],
                          size: 28,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Colors.grey[400],
                          size: 28,
                        ),
                        headerPadding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        weekendStyle: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        decoration: const BoxDecoration(),
                      ),
                      onDaySelected: _onDaySelected,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TableCalendar<BeeTask>(
                        firstDay: DateTime.now().subtract(const Duration(days: 365)),
                        lastDay: DateTime.now().add(const Duration(days: 365)),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        calendarFormat: CalendarFormat.month,
                        eventLoader: _getTaskEventsForCalendar,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        rowHeight: 52,
                        daysOfWeekHeight: 32,
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Colors.orange.shade400,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.orange.shade200.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: BoxDecoration(
                            color: Colors.orange.shade300,
                            shape: BoxShape.circle,
                          ),
                          weekendTextStyle: TextStyle(
                            color: Colors.grey[600],
                          ),
                          holidayTextStyle: TextStyle(
                            color: Colors.grey[600],
                          ),
                          markersMaxCount: 3,
                          markerSize: 5,
                          markersAlignment: Alignment.bottomCenter,
                          markerMargin: const EdgeInsets.only(top: 6),
                          todayTextStyle: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                          cellMargin: const EdgeInsets.all(4),
                          cellPadding: EdgeInsets.zero,
                          outsideTextStyle: TextStyle(
                            color: Colors.grey[350],
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                          leftChevronIcon: Icon(
                            Icons.chevron_left,
                            color: Colors.grey[600],
                            size: 28,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[600],
                            size: 28,
                          ),
                          headerPadding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          weekendStyle: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          decoration: const BoxDecoration(),
                        ),
                        onDaySelected: _onDaySelected,
                      ),
                    ),
            ),
            // Selected Day Items - combined list
            if (_selectedDay != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items for ${DateFormat('MMMM d, y').format(_selectedDay!)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCombinedList(_getItemsForDay(_selectedDay!)),
                  ],
                ),
              ),
            ],
            // Add some bottom padding
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: _isTeamCreator ? FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        label: const Text('Add Meeting'),
        icon: const Icon(Icons.add),
        tooltip: 'Add Meeting',
      ) : null,
    );
  }

  Widget _buildTaskList(List<BeeTask> tasks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
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
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  userName,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.grey[600],
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
                  ],
                ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BeeDetailScreen(taskId: task.id),
                ),
              ).then((_) => _loadTasks());
            },
          ),
        );
      },
    );
  }

  Widget _buildEventMarker(List<BeeTask> tasks) {
    if (tasks.isEmpty) return const SizedBox();

    // Group tasks by priority
    final workerTasks = tasks.where((t) => t.priority == BeePriority.worker).length;
    final warriorTasks = tasks.where((t) => t.priority == BeePriority.warrior).length;
    final queenTasks = tasks.where((t) => t.priority == BeePriority.queen).length;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (workerTasks > 0) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            if (workerTasks > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '$workerTasks',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
          if (warriorTasks > 0) ...[
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            if (warriorTasks > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '$warriorTasks',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
          if (queenTasks > 0) ...[
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            if (queenTasks > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '$queenTasks',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
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

  void _showCreateTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = _selectedDay!;
    TimeOfDay selectedTime = TimeOfDay.now();
    BeePriority selectedPriority = BeePriority.worker;
    String? selectedHiveId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Task'),
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
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('projects')
                    .where('teamId', isEqualTo: _currentTeamId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  
                  if (snapshot.hasError) {
                    return const Text('Error loading hives');
                  }
                  
                  final hives = snapshot.data?.docs ?? [];
                  
                  if (hives.isEmpty) {
                    return const Text('No hives available in this team');
                  }
                  
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Hive',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedHiveId,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No Hive (Personal Task)'),
                      ),
                      ...hives.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(data['name'] ?? 'Unnamed Hive'),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      selectedHiveId = value;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(
                  DateFormat('MMM d, y').format(selectedDate),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  
                  if (date != null) {
                    selectedDate = date;
                  }
                },
              ),
              ListTile(
                title: const Text('Time'),
                subtitle: Text(
                  selectedTime.format(context),
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  
                  if (time != null) {
                    selectedTime = time;
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
                    selectedPriority = value;
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
              
              try {
                // Combine date and time
                final dueDate = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                
                await FirebaseFirestore.instance
                    .collection('tasks')
                    .add({
                  'hiveId': selectedHiveId ?? '',  // Empty string if no hive selected
                  'teamId': _currentTeamId ?? '',  // Empty string if no team
                  'title': titleController.text,
                  'description': descriptionController.text,
                  'assignedTo': currentUserId,
                  'userId': currentUserId,
                  'createdBy': currentUserId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'dueDate': Timestamp.fromDate(dueDate),
                  'priority': selectedPriority.toString().split('.').last,
                  'status': 'todo',  // Use string directly to match query
                  'attachments': [],
                  'comments': [],
                  'tags': [],
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadTasks();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Task created successfully')),
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
      ),
    );
  }

  Widget _buildCombinedList(List<dynamic> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No items for this day',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    // Sort by type (events first) and then by time
    items.sort((a, b) {
      // First sort by type (Event before BeeTask)
      if (a is Event && b is BeeTask) {
        return -1;
      } else if (a is BeeTask && b is Event) {
        return 1;
      }
      
      // Then sort by time
      DateTime? timeA;
      DateTime? timeB;
      
      if (a is Event) {
        timeA = a.startTime;
      } else if (a is BeeTask) {
        timeA = a.dueDate;
      }
      
      if (b is Event) {
        timeB = b.startTime;
      } else if (b is BeeTask) {
        timeB = b.dueDate;
      }
      
      if (timeA != null && timeB != null) {
        return timeA.compareTo(timeB);
      }
      
      return 0;
    });
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        
        if (item is Event) {
          return _buildEventItem(item);
        } else if (item is BeeTask) {
          return _buildTaskItem(item);
        }
        
        return const SizedBox(); // Fallback
      },
    );
  }
  
  Widget _buildEventItem(Event event) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.deepOrange.shade300.withOpacity(0.2)
                : Colors.orange.shade300.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            event.isOnlineMeeting ? Icons.video_call : Icons.event,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.deepOrange.shade300
                : Colors.orange.shade700,
            size: 20,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                event.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.isOnlineMeeting ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    event.isOnlineMeeting ? Icons.link : Icons.location_on,
                    size: 12,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      event.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('h:mm a').format(event.startTime)} - ${DateFormat('h:mm a').format(event.endTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.people,
                    size: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${event.attendees.length} attendees',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(eventId: event.id),
            ),
          ).then((_) => _loadData());
        },
      ),
    );
  }
  
  Widget _buildTaskItem(BeeTask task) {
    // Skip the event marker placeholder
    if (task.id == 'event-marker') return const SizedBox();
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.withOpacity(0.2)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Task',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
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
                                ? Colors.grey[300]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              userName,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
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
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BeeDetailScreen(taskId: task.id),
            ),
          ).then((_) => _loadData());
        },
      ),
    );
  }

  Future<void> _showCreateEventDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final linkController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    TimeOfDay endTime = TimeOfDay(
      hour: TimeOfDay.now().hour + 1,
      minute: TimeOfDay.now().minute,
    );
    
    List<String> selectedAttendees = [];
    List<Map<String, dynamic>> teamMembers = [];
    bool isOnlineMeeting = true;
    
    // Load team members
    try {
      if (_currentTeamId != null) {
        final teamDoc = await FirebaseFirestore.instance
            .collection('teams')
            .doc(_currentTeamId)
            .get();
            
        if (teamDoc.exists) {
          final data = teamDoc.data() as Map<String, dynamic>;
          
          // Get list of members based on the structure (could be array or map)
          List<String> memberIds = [];
          if (data['members'] is List) {
            memberIds = List<String>.from(data['members']);
          } else if (data['members'] is Map) {
            memberIds = (data['members'] as Map).keys.cast<String>().toList();
          }
          
          // Get member details
          for (final memberId in memberIds) {
            if (memberId == currentUserId) continue; // Skip current user
            
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .get();
                
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              teamMembers.add({
                'id': memberId,
                'name': userData['name'] ?? 'Unknown User',
                'email': userData['email'] ?? '',
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading team members: $e');
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Meeting'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Meeting Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Meeting Type - Online or Offline
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meeting Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isOnlineMeeting = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: isOnlineMeeting
                                        ? Theme.of(context).brightness == Brightness.dark
                                            ? Colors.blue.shade800
                                            : Colors.blue.shade100
                                        : Colors.transparent,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.videocam,
                                        color: isOnlineMeeting
                                            ? Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.blue.shade800
                                            : Colors.grey,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Online',
                                        style: TextStyle(
                                          fontWeight: isOnlineMeeting ? FontWeight.bold : FontWeight.normal,
                                          color: isOnlineMeeting
                                              ? Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : Colors.blue.shade800
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isOnlineMeeting = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: !isOnlineMeeting
                                        ? Theme.of(context).brightness == Brightness.dark
                                            ? Colors.orange.shade800
                                            : Colors.orange.shade100
                                        : Colors.transparent,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: !isOnlineMeeting
                                            ? Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.orange.shade800
                                            : Colors.grey,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Offline',
                                        style: TextStyle(
                                          fontWeight: !isOnlineMeeting ? FontWeight.bold : FontWeight.normal,
                                          color: !isOnlineMeeting
                                              ? Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : Colors.orange.shade800
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Conditional field based on meeting type
                  if (isOnlineMeeting)
                    TextField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Link',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    )
                  else
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Location',
                        hintText: 'Enter physical location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(
                      DateFormat('MMM d, y').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(
                            startTime.format(context),
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            
                            if (time != null) {
                              setState(() {
                                startTime = time;
                                
                                // If end time is before start time, adjust it
                                if (endTime.hour < startTime.hour ||
                                    (endTime.hour == startTime.hour && endTime.minute < startTime.minute)) {
                                  endTime = TimeOfDay(
                                    hour: startTime.hour + 1,
                                    minute: startTime.minute,
                                  );
                                }
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time'),
                          subtitle: Text(
                            endTime.format(context),
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            
                            if (time != null) {
                              // Calculate if the new end time would make the event longer than 5 hours
                              final startDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                startTime.hour,
                                startTime.minute,
                              );
                              
                              final proposedEndDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                              
                              // Handle case where end time is earlier than start time (next day)
                              final adjustedEndDateTime = proposedEndDateTime.isBefore(startDateTime)
                                  ? proposedEndDateTime.add(const Duration(days: 1))
                                  : proposedEndDateTime;
                              
                              final duration = adjustedEndDateTime.difference(startDateTime);
                              
                              if (duration.inHours > 5) {
                                // Show error dialog if duration exceeds 5 hours
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Meeting duration cannot exceed 5 hours'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                setState(() {
                                  endTime = time;
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Attendees',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Host is automatically included note
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You (host) will be included automatically',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  teamMembers.isEmpty
                      ? const Text('No team members available')
                      : Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: selectedAttendees.length == teamMembers.length,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        // Select all members
                                        selectedAttendees = teamMembers
                                            .map((m) => m['id'] as String)
                                            .toList();
                                      } else {
                                        // Deselect all members
                                        selectedAttendees = [];
                                      }
                                    });
                                  },
                                ),
                                const Text('Select All Members'),
                              ],
                            ),
                            const Divider(),
                            ...teamMembers.map((member) {
                              final id = member['id'] as String;
                              return CheckboxListTile(
                                title: Text(member['name'] as String),
                                subtitle: Text(member['email'] as String),
                                value: selectedAttendees.contains(id),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedAttendees.add(id);
                                    } else {
                                      selectedAttendees.remove(id);
                                    }
                                  });
                                },
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            }).toList(),
                          ],
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
                      const SnackBar(content: Text('Please enter a meeting title')),
                    );
                    return;
                  }
                  
                  try {
                    // Create event
                    final startDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      startTime.hour,
                      startTime.minute,
                    );
                    
                    final endDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      endTime.hour,
                      endTime.minute,
                    );
                    
                    // Adjust end time if it's earlier than start time (next day)
                    final adjustedEndDateTime = endDateTime.isBefore(startDateTime)
                        ? endDateTime.add(const Duration(days: 1))
                        : endDateTime;
                    
                    // Verify event duration doesn't exceed 5 hours
                    final duration = adjustedEndDateTime.difference(startDateTime);
                    if (duration.inHours > 5) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Meeting duration cannot exceed 5 hours'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    // Always include current user (host) in attendees
                    if (currentUserId != null && !selectedAttendees.contains(currentUserId)) {
                      selectedAttendees.add(currentUserId!);
                    }
                    
                    // Add event to Firestore
                    await FirebaseFirestore.instance
                        .collection('events')
                        .add({
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'startTime': Timestamp.fromDate(startDateTime),
                      'endTime': Timestamp.fromDate(adjustedEndDateTime),
                      'teamId': _currentTeamId ?? '',
                      'createdBy': currentUserId ?? '',
                      'createdAt': FieldValue.serverTimestamp(),
                      'attendees': selectedAttendees,
                      'isOnlineMeeting': isOnlineMeeting,
                      'location': isOnlineMeeting ? linkController.text : locationController.text,
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Meeting created successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating meeting: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
} 