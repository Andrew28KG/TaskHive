import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/main.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class FocusScreen extends StatefulWidget {
  final String? teamId;
  const FocusScreen({super.key, this.teamId});

  // Static fields to maintain state between navigations, now user-specific
  static Map<String, BeeTask?> selectedTasks = {};
  static Map<String, int> selectedTimers = {};
  static Map<String, bool> isTimerRunning = {};
  static Map<String, Timer?> timers = {};
  static Map<String, int> remainingSeconds = {};
  // Updated to use composite key of userId_taskId for separate notes per task
  static Map<String, String> taskNotes = {};
  static bool hasInitializedAudio = false;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  List<BeeTask> _tasks = [];
  String? _currentTeamId;
  final _noteController = TextEditingController();
  final List<int> _timerOptions = [15, 25, 30, 45, 60];
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Get user-specific values
  BeeTask? get _selectedTask => 
      currentUserId != null ? FocusScreen.selectedTasks[currentUserId] : null;
  int get _selectedTimer => 
      currentUserId != null ? FocusScreen.selectedTimers[currentUserId] ?? 25 : 25;
  bool get _isTimerRunning => 
      currentUserId != null ? FocusScreen.isTimerRunning[currentUserId] ?? false : false;
  Timer? get _timer => 
      currentUserId != null ? FocusScreen.timers[currentUserId] : null;
  int get _remainingSeconds => 
      currentUserId != null ? FocusScreen.remainingSeconds[currentUserId] ?? 0 : 0;
  
  // Get task-specific notes using composite key
  String get _notes {
    if (currentUserId != null && _selectedTask != null) {
      final key = '${currentUserId}_${_selectedTask!.id}';
      return FocusScreen.taskNotes[key] ?? '';
    }
    return '';
  }

  // Set user-specific values
  set _selectedTask(BeeTask? value) {
    if (currentUserId != null) {
      FocusScreen.selectedTasks[currentUserId!] = value;
      
      // Load notes for the newly selected task
      if (value != null) {
        _loadTaskNotes(value.id);
      }
    }
  }
  
  set _selectedTimer(int value) {
    if (currentUserId != null) {
      FocusScreen.selectedTimers[currentUserId!] = value;
    }
  }
  
  set _isTimerRunning(bool value) {
    if (currentUserId != null) {
      FocusScreen.isTimerRunning[currentUserId!] = value;
    }
  }
  
  set _timer(Timer? value) {
    if (currentUserId != null) {
      FocusScreen.timers[currentUserId!] = value;
    }
  }
  
  set _remainingSeconds(int value) {
    if (currentUserId != null) {
      FocusScreen.remainingSeconds[currentUserId!] = value;
    }
  }
  
  // Set task-specific notes using composite key
  set _notes(String value) {
    if (currentUserId != null && _selectedTask != null) {
      final key = '${currentUserId}_${_selectedTask!.id}';
      FocusScreen.taskNotes[key] = value;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTeamId = widget.teamId;
    _loadTasks();

    // Add the listener for auto-saving notes
    _noteController.addListener(_autoSaveNotes);
    
    // Initialize audio if not done yet
    if (!FocusScreen.hasInitializedAudio) {
      _initializeAudio();
      FocusScreen.hasInitializedAudio = true;
    }
    
    // Restore timer if it was running
    if (_isTimerRunning && _timer == null) {
      _restartTimer();
    }
  }
  
  Future<void> _initializeAudio() async {
    // Pre-load the alarm sound
    try {
      await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
      print('Alarm sound loaded successfully');
    } catch (e) {
      print('Error loading alarm sound: $e');
    }
  }

  void _restartTimer() {
    // Restart the timer with the saved remaining seconds
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _timer = null;
          _isTimerRunning = false;
          _playAlarmSound();
          _showTimerCompleteDialog();
        }
      });
    });
  }
  
  void _playAlarmSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      // Vibrate the device
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error playing alarm sound: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save state when app goes to background
    if (state == AppLifecycleState.paused) {
      _saveCurrentState();
    }
  }

  void _saveCurrentState() {
    _notes = _noteController.text;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noteController.removeListener(_autoSaveNotes);
    _noteController.dispose();
    _audioPlayer.dispose();
    // We don't cancel the timer here to allow it to continue running
    super.dispose();
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
      
      // If we have a selected task, load its notes
      if (_selectedTask != null) {
        _loadTaskNotes(_selectedTask!.id);
      }
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadTaskNotes(String taskId) async {
    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();
          
      if (taskDoc.exists) {
        final notes = taskDoc.data()?['notes'] as String? ?? '';
        
        // Store in our taskNotes map with composite key
        if (currentUserId != null) {
          final key = '${currentUserId}_$taskId';
          FocusScreen.taskNotes[key] = notes;
          
          // Update the text controller if this is for the currently selected task
          if (_selectedTask != null && _selectedTask!.id == taskId) {
            setState(() {
              _noteController.text = notes;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading task notes: $e');
    }
  }

  void _startTimer() {
    setState(() {
      _remainingSeconds = _selectedTimer * 60;
      _isTimerRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _timer = null;
          _isTimerRunning = false;
          _playAlarmSound();
          _showTimerCompleteDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isTimerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _remainingSeconds = _selectedTimer * 60;
      _isTimerRunning = false;
    });
  }

  void _showTimerCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Focus Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'You completed ${_selectedTimer} minutes of focused work on "${_selectedTask!.title}"',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetTimer();
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateTaskStatus();
            },
            child: const Text('Mark Task as Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTaskStatus() async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(_selectedTask!.id)
          .update({
        'status': BeeStatus.done.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _loadTasks();
      setState(() => _selectedTask = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task marked as complete!')),
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _autoSaveNotes() {
    // Save to task-specific notes using composite key
    _notes = _noteController.text;
    
    if (_selectedTask != null) {
      FirebaseFirestore.instance
          .collection('tasks')
          .doc(_selectedTask!.id)
          .update({
        'notes': _noteController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
        child: _selectedTask == null
            ? _buildTaskSelection()
            : _buildFocusDetail(),
      ),
    );
  }

  Widget _buildTaskSelection() {
    return Column(
      children: [
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
                    : Colors.orange.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Focus Mode',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
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
                            'No tasks assigned to you',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join a team or get tasks assigned to start focusing',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _selectedTask = task),
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
                      },
                    ),
        ),
      ],
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

  Widget _buildFocusDetail() {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press by just hiding the detail screen
        setState(() => _selectedTask = null);
        return false; // Prevent app exit
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.deepOrange.shade900
                  : Colors.orange.shade400,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => setState(() => _selectedTask = null),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _selectedTask!.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Focus Timer',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            _formatDuration(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                              color: _isTimerRunning
                                  ? Theme.of(context).brightness == Brightness.dark
                                      ? Colors.deepOrange.shade300
                                      : Colors.amber.shade700
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: _timerOptions.map((minutes) {
                              final isSelected = minutes == _selectedTimer;
                              final color = Theme.of(context).brightness == Brightness.dark
                                  ? Colors.deepOrange
                                  : Colors.amber;
                              return InkWell(
                                onTap: () {
                                  if (!_isTimerRunning) {
                                    setState(() {
                                      _selectedTimer = minutes;
                                      _remainingSeconds = minutes * 60;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? color.withOpacity(0.1) : null,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? color : Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[600]!
                                          : Colors.grey[400]!,
                                    ),
                                  ),
                                  child: Text(
                                    '$minutes min',
                                    style: TextStyle(
                                      color: isSelected ? color : Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                                icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
                                label: Text(_isTimerRunning ? 'Pause' : 'Start Focus Timer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.deepOrange.shade700
                                      : Colors.amber.shade400,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              if (_isTimerRunning || _remainingSeconds < _selectedTimer * 60) ...[
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: _resetTimer,
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Reset Timer',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
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
                                Icons.edit_note,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.deepOrange.shade300
                                    : Colors.amber.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Session Notes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _noteController,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: 'Write your notes here... (Auto-saves as you type)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.deepOrange.shade300
                                      : Colors.amber.shade700,
                                ),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[900]
                                  : Colors.grey[100],
                            ),
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[300]
                                  : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Notes are automatically saved as you type',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
} 