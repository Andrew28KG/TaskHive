import 'package:flutter/material.dart';
import 'package:taskhive/utils/navigation_utils.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return BackNavigationHandler.wrapWithPopScope(
      onBackPress: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('App Tutorial'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 60),
          children: [
            _buildTutorialHeader(context),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Dashboard',
              Icons.dashboard,
              'Your main workspace where you can view all your teams and tasks.',
              [
                'View assigned tasks and events',
                'Add new hives/projects with the + button (admin only)',
                'Access team management from the drawer menu',
                'Edit task details and track progress',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Calendar',
              Icons.calendar_today,
              'Manage your schedule and deadlines in one place.',
              [
                'View tasks and events by date',
                'See all items scheduled for a specific day',
                'Create new meetings with online/offline options',
                'Manage attendees for meetings',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Progress',
              Icons.analytics,
              'Track your team\'s productivity and task completion.',
              [
                'View overall completion rate',
                'Check performance rating (1-5 stars)',
                'Monitor efficiency score',
                'Track overdue tasks',
                'See task status distribution',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Discussions',
              Icons.forum,
              'Stay connected with your team through dedicated chat channels.',
              [
                'Access the Team Chat for team-wide discussions',
                'Chat about specific tasks in task-specific channels',
                'Pin important messages for easy reference',
                'React to messages with likes',
                'Organize chats by hives/projects',
                'Pin frequently used chats for quick access',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Task Details',
              Icons.task_alt,
              'Comprehensive view of each task\'s information.',
              [
                'Update task status',
                'Add comments through Bee Chat',
                'View assignment details',
                'Track due dates',
                'Edit task details (admin only)',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Meeting Details',
              Icons.event,
              'Manage and coordinate online or in-person meetings.',
              [
                'View meeting timing and duration',
                'See full attendee list',
                'Check if meeting is online or in-person',
                'Access meeting location or video call link',
                'Edit meeting details (admin only)',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Focus Mode',
              Icons.center_focus_strong,
              'Boost productivity by focusing on one task at a time.',
              [
                'Select a task to focus on',
                'Track time spent on tasks',
                'Set work/break intervals',
                'Receive reminders to stay on track',
                'Update task progress directly',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'Navigation',
              Icons.menu,
              'Use the bottom navigation bar and drawer menu to access all features.',
              [
                'Bottom bar: Home, Chat, Progress, Calendar, Focus',
                'Open drawer menu by tapping the hamburger icon',
                'Access profile settings and team management in drawer',
                'Toggle dark mode in the drawer menu',
                'View app info and log out from the drawer',
              ],
            ),
            const SizedBox(height: 24),
            _buildTutorialSection(
              context,
              'More Menu',
              Icons.more_vert,
              'Access account settings and team options from the drawer menu.',
              [
                'Edit your profile information',
                'Change application theme (dark/light mode)',
                'Switch between teams or create new teams',
                'Manage team codes and membership',
                'Access help and about information',
                'Sign out of your account',
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTutorialHeader(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.deepOrange.shade900, Colors.deepOrange.shade700]
                    : [Colors.orange.shade400, Colors.orange.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to TaskHive',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your guide to getting the most out of the app',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'TaskHive helps you organize tasks, schedule meetings, and collaborate with your team efficiently. This guide will help you understand each feature and make the most of your experience.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTutorialSection(
    BuildContext context,
    String title,
    IconData icon,
    String description,
    List<String> features,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
                    color: isDarkMode
                        ? Colors.deepOrange.shade900.withOpacity(0.2)
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDarkMode
                        ? Colors.deepOrange.shade300
                        : Colors.orange.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Key Features:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: isDarkMode
                        ? Colors.deepOrange.shade300
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
} 