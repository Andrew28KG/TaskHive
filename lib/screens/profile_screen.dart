import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/screens/about_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  String _userRole = '';
  int _totalTasks = 0;
  int _completedTasks = 0;
  bool _isDarkMode = false;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    print('ProfileScreen initState called');
    _loadUserData();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() {
      _isDarkMode = value;
    });
    
    final appState = TaskHiveApp.of(context);
    if (appState != null) {
      appState.toggleTheme(value);
    }
  }

  Future<void> _loadUserData() async {
    print('Loading user data...');
    setState(() => _isLoading = true);
    
    try {
      final userId = currentUserId;
      print('Current user ID: $userId');
      
      if (userId == null) {
        print('No user signed in');
        setState(() {
          _userName = 'Not Signed In';
          _userEmail = '';
          _userRole = '';
          _totalTasks = 0;
          _completedTasks = 0;
          _isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      print('User document exists: ${userDoc.exists}');
      
      if (!userDoc.exists) {
        print('User document not found');
        setState(() {
          _userName = 'Unknown User';
          _userEmail = '';
          _userRole = 'Member';
          _totalTasks = 0;
          _completedTasks = 0;
          _isLoading = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', isEqualTo: userId)
          .get();

      final completedTasks = tasksSnapshot.docs
          .where((doc) => doc.data()['status'] == 'done')
          .length;

      print('Setting state with user data');
      setState(() {
        _userName = userDoc.data()?['name'] ?? 'Unknown User';
        _userEmail = user?.email ?? '';
        _userRole = userDoc.data()?['role'] ?? 'Member';
        _totalTasks = tasksSnapshot.docs.length;
        _completedTasks = completedTasks;
        _isLoading = false;
      });
      print('User data loaded successfully');
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'Error Loading Data';
        _userEmail = '';
        _userRole = '';
        _totalTasks = 0;
        _completedTasks = 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                  'Profile',
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildProfileHeader(),
                          const SizedBox(height: 24),
                          _buildStatsSection(),
                          const SizedBox(height: 24),
                          _buildActionSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.deepOrange.shade900
                  : Colors.orange.shade200,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _showEditUsernameDialog,
                        tooltip: 'Edit Username',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final completionRate = _totalTasks > 0 
        ? (_completedTasks / _totalTasks * 100).round()
        : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.deepOrange.shade300
                      : Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Task Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  'Total Tasks',
                  _totalTasks.toString(),
                  Icons.task_alt,
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.deepOrange.shade300
                      : Colors.orange.shade700,
                ),
                _buildStatItem(
                  'Completed',
                  _completedTasks.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                _buildStatItem(
                  'Completion Rate',
                  '$completionRate%',
                  Icons.pie_chart_outline,
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade300
                      : Colors.blue.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
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
            size: 24,
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

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        _buildActionButton(
          'Dark Mode',
          Icons.dark_mode,
          () {},
          trailing: Switch(
            value: _isDarkMode,
            onChanged: _toggleTheme,
            activeColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.deepOrange.shade300
                : Colors.orange.shade700,
          ),
        ),
        
        // Add security section
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Security',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        _buildActionButton(
          'Change Password',
          Icons.lock,
          _showChangePasswordDialog,
        ),
        
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'About',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        _buildActionButton(
          'About TaskHive',
          Icons.info,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          'Sign Out',
          Icons.logout,
          () async {
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
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed, {bool isDestructive = false, Widget? trailing}) {
    final color = isDestructive
        ? Colors.red
        : Theme.of(context).brightness == Brightness.dark
            ? Colors.deepOrange.shade300
            : Colors.orange.shade700;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.chevron_right,
                    color: color.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditUsernameDialog() {
    final nameController = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Username'),
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
                  _loadUserData(); // Reload user data to show the new username
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating username: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Add change password dialog
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrentPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: obscureCurrentPassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: obscureNewPassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: obscureConfirmPassword,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          // Validate inputs
                          if (currentPasswordController.text.isEmpty ||
                              newPasswordController.text.isEmpty ||
                              confirmPasswordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('All fields are required')),
                            );
                            return;
                          }

                          if (newPasswordController.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'New password must be at least 6 characters')),
                            );
                            return;
                          }

                          if (newPasswordController.text !=
                              confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Passwords do not match')),
                            );
                            return;
                          }

                          // Update password
                          setState(() {
                            isLoading = true;
                          });

                          try {
                            // Get current user
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              // Reauthenticate user first
                              final credential = EmailAuthProvider.credential(
                                email: user.email!,
                                password: currentPasswordController.text,
                              );

                              await user.reauthenticateWithCredential(credential);

                              // Change password
                              await user.updatePassword(
                                  newPasswordController.text);

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Password updated successfully')),
                                );
                              }
                            }
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error: ${e.toString()}')),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }
} 