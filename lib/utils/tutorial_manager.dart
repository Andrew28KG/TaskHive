import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialManager {
  // Tutorial keys for different screens
  static const String keySeen = 'tutorial_seen_';
  static const String keyDashboard = 'dashboard';
  static const String keyTask = 'task_details';
  static const String keyCalendar = 'calendar';
  static const String keyProfile = 'profile';
  static const String keyProgress = 'progress';
  static const String keyFocus = 'focus';
  static const String keyHive = 'hive_detail';
  
  // Check if the user has seen a specific tutorial
  static Future<bool> hasSeenTutorial(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$keySeen$tutorialKey') ?? false;
  }
  
  // Mark a tutorial as seen
  static Future<void> markTutorialAsSeen(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$keySeen$tutorialKey', true);
  }
  
  // Show tutorial dialog
  static Future<void> showTutorialDialog(
    BuildContext context, 
    String tutorialKey, 
    String title, 
    List<TutorialStep> steps,
  ) async {
    // First check if the user has already seen this tutorial
    if (await hasSeenTutorial(tutorialKey)) {
      return;
    }
    
    // Show tutorial dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TutorialDialog(
        title: title,
        steps: steps,
        onComplete: () => markTutorialAsSeen(tutorialKey),
      ),
    );
  }
  
  // Method to show initial welcome tutorial for newcomers
  static Future<void> showWelcomeTutorial(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownWelcome = prefs.getBool('has_shown_welcome_tutorial') ?? false;
    
    if (!hasShownWelcome) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.emoji_nature, 
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.deepOrange.shade300 
                    : Colors.orange.shade600,
              ),
              const SizedBox(width: 8),
              const Text('Welcome to TaskHive!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your new productivity companion is ready to go! Each section of the app has helpful tutorials to guide you.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Look for tutorial popups on each screen to learn about features.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                prefs.setBool('has_shown_welcome_tutorial', true);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.deepOrange.shade700 
                    : Colors.orange.shade600,
              ),
              child: const Text('Got it!'),
            ),
          ],
        ),
      );
    }
  }
  
  // Force show tutorial regardless of previous views (for demo/testing)
  static Future<void> forceShowTutorial(
    BuildContext context, 
    String tutorialKey, 
    String title, 
    List<TutorialStep> steps,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TutorialDialog(
        title: title,
        steps: steps,
        onComplete: () => markTutorialAsSeen(tutorialKey),
      ),
    );
  }
  
  // Reset all tutorials (for testing)
  static Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${keySeen}$keyDashboard');
    await prefs.remove('${keySeen}$keyTask');
    await prefs.remove('${keySeen}$keyCalendar');
    await prefs.remove('${keySeen}$keyProfile');
    await prefs.remove('${keySeen}$keyProgress');
    await prefs.remove('${keySeen}$keyFocus');
    await prefs.remove('${keySeen}$keyHive');
    await prefs.remove('has_shown_welcome_tutorial');
  }
  
  // Replay a specific tutorial regardless of whether it has been seen before
  static Future<void> replayTutorial(BuildContext context, String tutorialKey) async {
    String title;
    List<TutorialStep> steps;
    
    // Get the appropriate tutorial title and steps
    switch (tutorialKey) {
      case keyDashboard:
        title = 'Dashboard';
        steps = getDashboardTutorialSteps();
        break;
      case keyTask:
        title = 'Task Details';
        steps = getTaskDetailsTutorialSteps();
        break;
      case keyCalendar:
        title = 'Calendar';
        steps = getCalendarTutorialSteps();
        break;
      case keyProfile:
        title = 'Profile';
        steps = getProfileTutorialSteps();
        break;
      case keyProgress:
        title = 'Progress Tracking';
        steps = getProgressTutorialSteps();
        break;
      case keyFocus:
        title = 'Focus Mode';
        steps = getFocusTutorialSteps();
        break;
      case keyHive:
        title = 'Hive Details';
        steps = getHiveDetailTutorialSteps();
        break;
      default:
        title = 'Tutorial';
        steps = getDashboardTutorialSteps();
    }
    
    // Show the tutorial without checking if it has been seen
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TutorialDialog(
        title: title,
        steps: steps,
        onComplete: () {}, // No need to mark as seen since it may have already been seen
      ),
    );
  }
  
  // Dashboard tutorial steps
  static List<TutorialStep> getDashboardTutorialSteps() {
    return [
      TutorialStep(
        title: 'Welcome to TaskHive!',
        description: 'Your central hub for task and team management. Let\'s explore the key features.',
        icon: Icons.dashboard,
      ),
      TutorialStep(
        title: 'Hives',
        description: 'Hives are projects or categories for your tasks. Create hives to organize your work.',
        icon: Icons.grid_view,
      ),
      TutorialStep(
        title: 'Tasks',
        description: 'Each task is assigned a priority: Worker Bee (regular), Warrior Bee (urgent), or Queen Bee (important).',
        icon: Icons.task_alt,
      ),
      TutorialStep(
        title: 'Team Members',
        description: 'View your team members and their roles. Admins can manage the team and assign tasks.',
        icon: Icons.people,
      ),
      TutorialStep(
        title: 'Navigation',
        description: 'Use the bottom navigation to access Calendar, Progress reports, and Profile settings.',
        icon: Icons.menu,
      ),
    ];
  }
  
  // Task details tutorial steps
  static List<TutorialStep> getTaskDetailsTutorialSteps() {
    return [
      TutorialStep(
        title: 'Task Details',
        description: 'Here you can view and manage a specific task.',
        icon: Icons.assignment,
      ),
      TutorialStep(
        title: 'Task Status',
        description: 'Update the status of your task: To Do, Busy Bee (in progress), or Done.',
        icon: Icons.refresh,
      ),
      TutorialStep(
        title: 'Comments',
        description: 'Use Bee Chat to communicate with your team about this task.',
        icon: Icons.chat_bubble_outline,
      ),
      TutorialStep(
        title: 'Assignment',
        description: 'Tasks are assigned to team members. Only assigned members or admins can change status.',
        icon: Icons.person_outline,
      ),
    ];
  }
  
  // Calendar tutorial steps
  static List<TutorialStep> getCalendarTutorialSteps() {
    return [
      TutorialStep(
        title: 'Calendar View',
        description: 'Get a visual overview of your tasks and events by date.',
        icon: Icons.calendar_today,
      ),
      TutorialStep(
        title: 'Select Dates',
        description: 'Tap on a date to see tasks and events scheduled for that day.',
        icon: Icons.date_range,
      ),
      TutorialStep(
        title: 'Add Events',
        description: 'Admins can add team events and meetings from the calendar screen.',
        icon: Icons.event,
      ),
      TutorialStep(
        title: 'Task Due Dates',
        description: 'Tasks with due dates appear on their respective days in the calendar.',
        icon: Icons.event_note,
      ),
    ];
  }
  
  // Progress screen tutorial steps
  static List<TutorialStep> getProgressTutorialSteps() {
    return [
      TutorialStep(
        title: 'Progress Overview',
        description: 'Track your team\'s performance and task completion metrics.',
        icon: Icons.insights,
      ),
      TutorialStep(
        title: 'Performance Rating',
        description: 'The star rating shows overall performance based on meeting deadlines and early completions.',
        icon: Icons.star,
      ),
      TutorialStep(
        title: 'Efficiency Score',
        description: 'The efficiency score measures how quickly and effectively tasks are completed.',
        icon: Icons.speed,
      ),
      TutorialStep(
        title: 'Overdue Tasks',
        description: 'The red overdue indicator shows tasks past their due date that need attention.',
        icon: Icons.warning_amber,
      ),
    ];
  }
  
  // Profile tutorial steps
  static List<TutorialStep> getProfileTutorialSteps() {
    return [
      TutorialStep(
        title: 'Profile Settings',
        description: 'Manage your account and preferences here.',
        icon: Icons.person,
      ),
      TutorialStep(
        title: 'Dark Mode',
        description: 'Toggle between light and dark themes based on your preference.',
        icon: Icons.dark_mode,
      ),
      TutorialStep(
        title: 'Security',
        description: 'Change your password and manage security settings.',
        icon: Icons.security,
      ),
      TutorialStep(
        title: 'Statistics',
        description: 'View your personal task statistics like completion rate.',
        icon: Icons.bar_chart,
      ),
    ];
  }
  
  // Focus mode tutorial steps
  static List<TutorialStep> getFocusTutorialSteps() {
    return [
      TutorialStep(
        title: 'Focus Mode',
        description: 'A distraction-free environment to help you concentrate on your tasks.',
        icon: Icons.do_not_disturb,
      ),
      TutorialStep(
        title: 'Pomodoro Timer',
        description: 'Use the Pomodoro technique: work for focused intervals with short breaks in between.',
        icon: Icons.timer,
      ),
      TutorialStep(
        title: 'Task Selection',
        description: 'Select the task you want to focus on. This helps track your effort and provides context.',
        icon: Icons.checklist,
      ),
      TutorialStep(
        title: 'Session History',
        description: 'View your past focus sessions to track productivity and patterns over time.',
        icon: Icons.history,
      ),
    ];
  }
  
  // Hive detail tutorial steps
  static List<TutorialStep> getHiveDetailTutorialSteps() {
    return [
      TutorialStep(
        title: 'Hive Overview',
        description: 'This is your project workspace. Here you can manage all tasks within this hive.',
        icon: Icons.hive,
      ),
      TutorialStep(
        title: 'Task Management',
        description: 'Create, assign, and organize tasks. Drag tasks between columns to update their status.',
        icon: Icons.drag_indicator,
      ),
      TutorialStep(
        title: 'Progress Tracking',
        description: 'Monitor project completion with the progress bar. Click on it to see detailed metrics.',
        icon: Icons.analytics,
      ),
      TutorialStep(
        title: 'Task Filtering',
        description: 'Use filters to focus on specific priorities, assignees, or status categories.',
        icon: Icons.filter_list,
      ),
    ];
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  
  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class TutorialDialog extends StatefulWidget {
  final String title;
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  
  const TutorialDialog({
    super.key,
    required this.title,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int _currentStep = 0;
  late PageController _pageController;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Mark tutorial as seen and close dialog
      widget.onComplete();
      Navigator.of(context).pop();
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.lightbulb,
            color: isDarkMode ? Colors.deepOrange.shade300 : Colors.orange.shade600,
          ),
          const SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.steps.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                itemBuilder: (context, index) {
                  final step = widget.steps[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.deepOrange.shade900.withOpacity(0.2) 
                              : Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon,
                          size: 40,
                          color: isDarkMode 
                              ? Colors.deepOrange.shade300 
                              : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.steps.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentStep
                        ? (isDarkMode ? Colors.deepOrange.shade300 : Colors.orange.shade600)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_currentStep > 0)
          TextButton(
            onPressed: _previousStep,
            child: const Text('Back'),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? Colors.deepOrange.shade700 : Colors.orange.shade600,
          ),
          child: Text(_currentStep < widget.steps.length - 1 ? 'Next' : 'Got it!'),
        ),
      ],
    );
  }
} 