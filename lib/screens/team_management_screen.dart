import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/screens/dashboard_screen.dart';
import 'package:taskhive/utils/logger.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _pendingInvites = [];
  String? _selectedTeamId;
  bool _isTeamCreator = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = currentUserId;
      
      if (userId == null) {
        logger.warning('User not authenticated. currentUserId is null.');
        setState(() => _isLoading = false);
        return;
      }
      
      logger.info('Loading teams for user: $userId');
      
      // Get teams where user is a member
      final teamsSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('members.$userId', isEqualTo: true)
          .get();
      
      logger.info('Found ${teamsSnapshot.docs.length} teams where user is a member');
      
      // Get teams with pending invites
      final invitesSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('pendingInvites.$userId', isEqualTo: true)
          .get();
      
      logger.info('Found ${invitesSnapshot.docs.length} teams with pending invites');
      
      setState(() {
        _teams = teamsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed Team',
            'description': data['description'] ?? '',
            'createdBy': data['createdBy'] ?? '',
            'createdAt': data['createdAt'] ?? Timestamp.now(),
            'members': data['members'] ?? {},
            'pendingInvites': data['pendingInvites'] ?? {},
          };
        }).toList();
        
        _pendingInvites = invitesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unnamed Team',
            'description': data['description'] ?? '',
            'createdBy': data['createdBy'] ?? '',
            'createdAt': data['createdAt'] ?? Timestamp.now(),
            'members': data['members'] ?? {},
            'pendingInvites': data['pendingInvites'] ?? {},
          };
        }).toList();
        
        _isLoading = false;
        if (_selectedTeamId != null) {
          final selectedTeam = _teams.firstWhere(
            (team) => team['id'] == _selectedTeamId,
            orElse: () => _teams.first,
          );
          _isTeamCreator = selectedTeam['createdBy'] == currentUserId;
        }
      });
    } catch (e) {
      logger.severe('Error loading teams', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createTeam(String name, String description) async {
    final userId = currentUserId;
    
    if (userId == null) {
      logger.warning('User not authenticated. currentUserId is null.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to create a team')),
        );
      }
      return;
    }
    
    logger.info('Creating team with name: $name, description: $description');
    logger.info('Current user ID: $userId');
    
    try {
      setState(() => _isLoading = true);
      
      // Create team data
      final teamData = {
        'name': name,
        'description': description,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'members': {userId: true},
        'pendingInvites': {},
      };
      
      logger.info('Team data to be created: $teamData');
      
      // Add team to Firestore
      final teamDoc = await FirebaseFirestore.instance.collection('teams').add(teamData);
      
      logger.info('Team created with ID: ${teamDoc.id}');
      
      // Update user's teams
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'teams': FieldValue.arrayUnion([teamDoc.id]),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created successfully')),
        );
        
        // Navigate to dashboard with the new team ID
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(teamId: teamDoc.id),
          ),
        );
      }
    } catch (e) {
      logger.severe('Error creating team', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating team: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptInvite(String teamId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('User not authenticated. currentUserId is null.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to accept an invitation')),
          );
        }
        return;
      }
      
      logger.info('Accepting invite for team: $teamId');
      
      final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final teamDoc = await transaction.get(teamRef);
        
        if (!teamDoc.exists) {
          throw Exception('Team does not exist');
        }
        
        final teamData = teamDoc.data() as Map<String, dynamic>;
        final pendingInvites = teamData['pendingInvites'] as Map<String, dynamic>? ?? {};
        
        if (!pendingInvites.containsKey(userId)) {
          throw Exception('No pending invite for this user');
        }
        
        // Remove from pending invites and add to members
        final updatedPendingInvites = Map<String, dynamic>.from(pendingInvites)
          ..remove(userId);
        
        final members = teamData['members'] as Map<String, dynamic>? ?? {};
        final updatedMembers = Map<String, dynamic>.from(members)
          ..addAll({userId: true});
        
        transaction.update(teamRef, {
          'pendingInvites': updatedPendingInvites,
          'members': updatedMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      
      // Update user's teams
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'teams': FieldValue.arrayUnion([teamId]),
      });
      
      _loadTeams();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation accepted')),
        );
      }
    } catch (e) {
      logger.severe('Error accepting invitation', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting invitation: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _declineInvite(String teamId) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        logger.warning('User not authenticated. currentUserId is null.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to decline an invitation')),
          );
        }
        return;
      }
      
      logger.info('Declining invite for team: $teamId');
      
      final teamRef = FirebaseFirestore.instance.collection('teams').doc(teamId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final teamDoc = await transaction.get(teamRef);
        
        if (!teamDoc.exists) {
          throw Exception('Team does not exist');
        }
        
        final teamData = teamDoc.data() as Map<String, dynamic>;
        final pendingInvites = teamData['pendingInvites'] as Map<String, dynamic>? ?? {};
        
        if (!pendingInvites.containsKey(userId)) {
          throw Exception('No pending invite for this user');
        }
        
        // Remove from pending invites
        final updatedPendingInvites = Map<String, dynamic>.from(pendingInvites)
          ..remove(userId);
        
        transaction.update(teamRef, {
          'pendingInvites': updatedPendingInvites,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      
      _loadTeams();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined')),
        );
      }
    } catch (e) {
      logger.severe('Error declining invitation', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining invitation: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _disbandTeam(String teamId) async {
    final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return;

    // Get members as a List
    final members = List<String>.from(teamDoc.data()?['members'] ?? []);

    // Delete all hives and tasks associated with the team
    final hivesSnapshot = await FirebaseFirestore.instance
        .collection('hives')
        .where('teamId', isEqualTo: teamId)
        .get();

    for (var hive in hivesSnapshot.docs) {
      // Delete all tasks in the hive
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('hiveId', isEqualTo: hive.id)
          .get();

      for (var task in tasksSnapshot.docs) {
        await task.reference.delete();
      }

      // Delete the hive
      await hive.reference.delete();
    }

    // Update team members' references
    for (String memberId in members) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(memberId).get();
      if (userDoc.exists) {
        List<String> userTeams = List<String>.from(userDoc.data()?['teams'] ?? []);
        userTeams.remove(teamId);
        await userDoc.reference.update({'teams': userTeams});
      }
    }

    // Delete the team document
    await FirebaseFirestore.instance.collection('teams').doc(teamId).delete();

    if (mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team successfully disbanded')),
      );

      // Reset selected team and refresh the screen
      setState(() {
        _selectedTeamId = null;
      });
      _loadTeams();
    }
  }

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Team'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Team Name',
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
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a team name')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Creating team...'),
                    ],
                  ),
                  duration: Duration(seconds: 1),
                ),
              );
              
              await _createTeam(nameController.text, descriptionController.text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_isTeamCreator && _selectedTeamId != null)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () => _disbandTeam(_selectedTeamId!),
              tooltip: 'Disband Team',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTeamDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_teams.isEmpty && _pendingInvites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Teams Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a team to start collaborating',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Team'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingInvites.isNotEmpty) ...[
            const Text(
              'Team Invitations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildInvitesList(),
            const SizedBox(height: 24),
          ],
          
          const Text(
            'Your Teams',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildTeamsList(),
        ],
      ),
    );
  }

  Widget _buildInvitesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pendingInvites.length,
      itemBuilder: (context, index) {
        final team = _pendingInvites[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              team['name'] as String,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((team['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(team['description'] as String),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _declineInvite(team['id'] as String),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _acceptInvite(team['id'] as String),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamsList() {
    if (_teams.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.group,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'No teams yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new team to get started',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        final isSelected = _selectedTeamId == team['id'];
        final isCreator = team['createdBy'] == currentUserId;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                : BorderSide.none,
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  team['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((team['description'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(team['description'] as String),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${(team['members'] as List).length} members',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCreator)
                      IconButton(
                        icon: const Icon(Icons.delete_forever),
                        color: Colors.red,
                        onPressed: () => _disbandTeam(team['id'] as String),
                        tooltip: 'Disband Team',
                      ),
                    if (isSelected)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DashboardScreen(teamId: team['id'] as String),
                            ),
                          );
                        },
                        child: const Text('Open'),
                      ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _selectedTeamId = team['id'] as String;
                  });
                },
              ),
              if (isCreator && isSelected)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _disbandTeam(team['id'] as String),
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text(
                            'Disband Team',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
} 