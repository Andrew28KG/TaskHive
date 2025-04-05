import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:taskhive/main.dart';
import 'dart:math';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _isLoading = false;
  final _teamNameController = TextEditingController();
  final _teamDescriptionController = TextEditingController();
  final _teamCodeController = TextEditingController();

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamDescriptionController.dispose();
    _teamCodeController.dispose();
    super.dispose();
  }

  void _showCreateTeamDialog() {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Create New Team',
          style: theme.textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _teamNameController,
                decoration: InputDecoration(
                  labelText: 'Team Name',
                  prefixIcon: const Icon(Icons.group),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _teamDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Team Description',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _teamNameController.clear();
              _teamDescriptionController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createTeam();
            },
            child: const Text(
              'Create',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTeam() async {
    if (_teamNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate a 6-digit code
      final random = Random();
      final inviteCode = (100000 + random.nextInt(900000)).toString();
      
      // Check if code already exists
      final existingTeam = await FirebaseFirestore.instance
          .collection('teams')
          .where('inviteCode', isEqualTo: inviteCode)
          .get();
      
      if (existingTeam.docs.isNotEmpty) {
        throw 'Code generation conflict. Please try again.';
      }
      
      // Create new team
      final teamRef = await FirebaseFirestore.instance.collection('teams').add({
        'name': _teamNameController.text,
        'description': _teamDescriptionController.text,
        'createdBy': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'members': [currentUserId],
        'inviteCode': inviteCode,
      });

      // Update user's team reference
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'currentTeamId': teamRef.id,
      });

      if (mounted) {
        // Show success dialog with invite code
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              'Team Created!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Share this code with your team members:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surfaceVariant
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
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
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          // TODO: Implement copy to clipboard
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
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);  // Close dialog
                  // Navigate to dashboard with the new team ID
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/dashboard',
                    (route) => false,
                    arguments: teamRef.id,
                  );
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating team: ${e.toString()}')),
        );
      }
    
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _teamNameController.clear();
      _teamDescriptionController.clear();
    }
  }

  Future<void> _joinTeam() async {
    if (_teamCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Find team by invite code
      final teamQuery = await FirebaseFirestore.instance
          .collection('teams')
          .where('inviteCode', isEqualTo: _teamCodeController.text)
          .get();

      if (teamQuery.docs.isEmpty) {
        throw 'Invalid team code';
      }

      final teamDoc = teamQuery.docs.first;
      
      // Add user to team
      await teamDoc.reference.update({
        'members': FieldValue.arrayUnion([currentUserId]),
      });

      // Update user's team reference
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'teamId': teamDoc.id,
        'teamRole': 'member',
      });

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining team: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _teamCodeController.clear();
    }
  }

  void _showJoinTeamDialog() {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Join Team',
          style: theme.textTheme.titleLarge,
        ),
        content: TextField(
          controller: _teamCodeController,
          decoration: InputDecoration(
            labelText: 'Enter Team Code',
            prefixIcon: const Icon(Icons.key),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _teamCodeController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinTeam();
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.brightness == Brightness.dark
                    ? theme.colorScheme.surface
                    : Colors.amber.shade200,
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.groups,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your Hives',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your team memberships',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('teams')
                        .where('members', arrayContains: currentUserId)
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

                      final teams = snapshot.data?.docs ?? [];

                      if (teams.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.group_off,
                                    size: 64,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No teams yet',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create or join a team to get started',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: teams.length,
                        itemBuilder: (context, index) {
                          final team = teams[index].data() as Map<String, dynamic>;
                          final isAdmin = team['createdBy'] == currentUserId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber.shade100,
                                child: Icon(
                                  Icons.group,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                              title: Text(
                                team['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (team['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(team['description'] as String),
                                  ],
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAdmin
                                          ? Colors.amber.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isAdmin ? 'Admin' : 'Member',
                                      style: TextStyle(
                                        color: isAdmin
                                            ? Colors.amber.shade900
                                            : Colors.grey.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () async {
                                  try {
                                    // Update user's active team
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(currentUserId)
                                        .update({
                                      'currentTeamId': teams[index].id,
                                    });
                                    
                                    if (mounted) {
                                      // Navigate to dashboard with the team ID
                                      Navigator.of(context).pushNamedAndRemoveUntil(
                                        '/dashboard',
                                        (route) => false,
                                        arguments: teams[index].id,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error updating team: ${e.toString()}')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showCreateTeamDialog,
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Create Team',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showJoinTeamDialog,
                          icon: const Icon(Icons.group_add),
                          label: const Text(
                            'Join Team',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  child: TextButton.icon(
                    onPressed: () async {
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
                            SnackBar(
                              content: Text('Error signing out: ${e.toString()}'),
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      Icons.logout,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 