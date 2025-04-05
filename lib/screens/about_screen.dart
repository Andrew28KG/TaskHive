import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.amber.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.deepOrange.shade900
                          : Colors.amber.shade300,
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.deepOrange.shade700
                          : Colors.amber.shade100,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black26
                          : Colors.amber.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'About TaskHive',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
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
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Profile'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.deepOrange.shade300
                              : Colors.amber.shade700,
                        ),
                      ),
                    ),
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
                  color: Theme.of(context).brightness == Brightness.dark
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[300]
                    : Colors.grey[800],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 