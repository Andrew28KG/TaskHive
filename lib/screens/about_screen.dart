import 'package:flutter/material.dart';
import 'package:taskhive/utils/navigation_utils.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
          title: const Text('About TaskHive'),
          elevation: 0,
        ),
        body: Container(
          color: isDarkMode ? Colors.black : Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 60), // Add bottom padding to prevent navbar overlap
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        context,
                        'About the App',
                        'TaskHive is a collaborative task management app designed to help teams work together efficiently. Like bees in a hive, users can organize tasks, track progress, communicate through discussions, and achieve goals together.',
                        Icons.info_outline,
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Key Features',
                        '• Team collaboration with roles and permissions\n'
                        '• Task organization with priority levels (Worker, Warrior, Queen)\n'
                        '• Focus mode with Pomodoro timer\n'
                        '• Calendar view with online/offline meeting options\n'
                        '• Comprehensive discussion system with Team Chat\n'
                        '• Pin important messages and discussions\n'
                        '• Progress tracking and analytics\n'
                        '• Improved navigation with proper back button handling\n'
                        '• Dark mode support',
                        Icons.star_outline,
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Recent Updates',
                        '• Added ability to pin messages in Team Chat\n'
                        '• Improved navigation with BackNavigationHandler\n'
                        '• Enhanced UI for the Discussions screen\n'
                        '• Added online/offline meeting options\n'
                        '• Optimized notification system - limited to once per day\n'
                        '• Fixed Firestore query issues in discussions',
                        Icons.new_releases_outlined,
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Version',
                        'TaskHive v1.2.0',
                        Icons.numbers,
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Technology',
                        '• Built with Flutter for cross-platform compatibility\n'
                        '• Firebase for backend and authentication\n'
                        '• Firestore for real-time database\n'
                        '• Cloud Functions for notifications\n'
                        '• Material Design for UI components',
                        Icons.code,
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        'Credits',
                        'Developed with Flutter and Firebase\n'
                        'Icons by Material Design\n'
                        'Special thanks to all contributors',
                        Icons.favorite_outline,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content, IconData icon) {
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
                Icon(
                  icon,
                  color: isDarkMode
                      ? Colors.deepOrange.shade300
                      : Colors.amber.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 