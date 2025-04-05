import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
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
                      'TaskHive is a collaborative task management app designed to help teams work together efficiently. Like bees in a hive, users can organize tasks, track progress, and achieve goals together.',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Features',
                      '• Team collaboration with roles and permissions\n'
                      '• Task organization with priority levels\n'
                      '• Focus mode with Pomodoro timer\n'
                      '• Calendar view for task scheduling\n'
                      '• Dark mode support',
                      Icons.star_outline,
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Version',
                      'TaskHive v1.0.0',
                      Icons.new_releases_outlined,
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