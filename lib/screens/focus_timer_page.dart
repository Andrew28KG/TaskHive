import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/main.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class FocusTimerPage extends StatefulWidget {
  final BeeTask task;
  
  const FocusTimerPage({super.key, required this.task});

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage> with WidgetsBindingObserver {
  // Timer state
  late Timer? _timer;
  bool _isTimerRunning = false;
  int _remainingSeconds = 0;
  int _selectedTimer = 25; // Default 25 min
  final List<int> _timerOptions = [15, 25, 30, 45, 60];
  
  // Audio and notes
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _noteController = TextEditingController();
  String _notes = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAudio();
    _loadTaskNotes();
    
    // Initialize timer with default time
    _remainingSeconds = _selectedTimer * 60;
  }
  
  Future<void> _initializeAudio() async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/alarm.mp3'));
    } catch (e) {
      print('Error loading alarm sound: $e');
    }
  }
  
  Future<void> _loadTaskNotes() async {
    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .get();
          
      if (taskDoc.exists) {
        setState(() {
          _notes = taskDoc.data()?['notes'] as String? ?? '';
          _noteController.text = _notes;
        });
      }
    } catch (e) {
      print('Error loading task notes: $e');
    }
    
    // Add listener after loading initial notes
    _noteController.addListener(_autoSaveNotes);
  }
  
  void _autoSaveNotes() {
    _notes = _noteController.text;
    
    FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.task.id)
        .update({
      'notes': _noteController.text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Auto-save when app is backgrounded
      _saveCurrentState();
    }
  }
  
  void _saveCurrentState() {
    _notes = _noteController.text;
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _noteController.removeListener(_autoSaveNotes);
    _noteController.dispose();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
  
  void _playAlarmSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
      // Vibrate the device
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error playing alarm sound: $e');
    }
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
              'You completed ${_selectedTimer} minutes of focused work on "${widget.task.title}"',
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
              _markTaskAsDone();
            },
            child: const Text('Mark Task as Done'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _markTaskAsDone() async {
    try {
      await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.task.id)
        .update({
          'status': 'done',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task marked as complete!')),
      );
      
      // Return to focus list
      if (mounted) {
        Navigator.pop(context);
      }
      
    } catch (e) {
      print('Error marking task as done: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isTimerRunning,
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        // If timer running, show dialog
        if (_isTimerRunning) {
          _showExitConfirmationDialog();
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Focus Timer Header
            SliverAppBar(
              expandedHeight: 80,
              pinned: true,
              elevation: 0,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.deepOrange.shade900
                : Colors.orange.shade400,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_isTimerRunning) {
                    _showExitConfirmationDialog();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Focus Timer',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                centerTitle: true,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task details
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.task.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (widget.task.description.isNotEmpty) ...[
                              Text(
                                widget.task.description,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.task.dueDate != null
                                      ? 'Due: ${DateFormat('MMM d, y').format(widget.task.dueDate!)}'
                                      : 'No due date',
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
                    const SizedBox(height: 16),
                    // Timer section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Focus Timer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.orange[300]
                                    : Colors.orange[700],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _isTimerRunning
                                ? _buildRunningTimer()
                                : _buildTimerSelection(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Notes section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Add notes as you work...',
                                contentPadding: EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Mark as done button
                    if (widget.task.status != 'done')
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _markTaskAsDone,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Mark as Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    // Add extra padding at the bottom
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimerSelection() {
    return Column(
      children: [
        Text(
          _formatDuration(_remainingSeconds),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _startTimer,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ..._timerOptions.map((minutes) {
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
            // Custom timer button
            InkWell(
              onTap: () {
                if (!_isTimerRunning) {
                  _showCustomTimerDialog();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]!
                        : Colors.grey[400]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Custom',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildRunningTimer() {
    final minutes = (_remainingSeconds / 60).floor();
    final seconds = _remainingSeconds % 60;
    
    return Column(
      children: [
        Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.orange[300]
                : Colors.orange[700],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pauseTimer,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.deepOrange.shade700
                    : Colors.orange.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: _resetTimer,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Timer',
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ],
        ),
      ],
    );
  }
  
  void _showCustomTimerDialog() {
    int selectedHours = 0;
    int selectedMinutes = 0;
    int selectedSeconds = 0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Custom Timer'),
          content: SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ListWheelScrollView(
                    itemExtent: 50,
                    perspective: 0.01,
                    diameterRatio: 1.2,
                    useMagnifier: true,
                    magnification: 1.1,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (value) {
                      selectedHours = value;
                    },
                    children: List.generate(
                      24,
                      (index) => Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Text(
                  'h',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListWheelScrollView(
                    itemExtent: 50,
                    perspective: 0.01,
                    diameterRatio: 1.2,
                    useMagnifier: true,
                    magnification: 1.1,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (value) {
                      selectedMinutes = value;
                    },
                    children: List.generate(
                      60,
                      (index) => Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Text(
                  'm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListWheelScrollView(
                    itemExtent: 50,
                    perspective: 0.01,
                    diameterRatio: 1.2,
                    useMagnifier: true,
                    magnification: 1.1,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (value) {
                      selectedSeconds = value;
                    },
                    children: List.generate(
                      60,
                      (index) => Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Text(
                  's',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
              onPressed: () {
                final totalSeconds = (selectedHours * 3600) + (selectedMinutes * 60) + selectedSeconds;
                if (totalSeconds > 0) {
                  // Close the dialog first
                  Navigator.pop(context);
                  // Then update the parent widget's state
                  setState(() {
                    _selectedTimer = totalSeconds ~/ 60;
                    _remainingSeconds = totalSeconds;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a valid time'),
                    ),
                  );
                }
              },
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Confirmation'),
        content: const Text('Timer is still running. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to focus list
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
} 