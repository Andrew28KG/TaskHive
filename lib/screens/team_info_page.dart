import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/main.dart';

class TeamInfoPage extends StatefulWidget {
  const TeamInfoPage({super.key});

  @override
  State<TeamInfoPage> createState() => _TeamInfoPageState();
}

class _TeamInfoPageState extends State<TeamInfoPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _teamData;
  List<Map<String, dynamic>> _members = [];
  String? _currentTeamId;

  @override
  void initState() {
    super.initState();
    _loadTeamInfo();
  }

  Future<void> _loadTeamInfo() async {
    setState(() => _isLoading = true);
    try {
      // Get current team ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      _currentTeamId = userDoc.data()?['currentTeamId'];
      
      if (_currentTeamId != null) {
        // Get team data
        final teamDoc = await FirebaseFirestore.instance
            .collection('teams')
            .doc(_currentTeamId)
            .get();
        
        _teamData = teamDoc.data();

        if (_teamData != null) {
          List<String> memberIds = [];
          
          // Handle different formats of members in the data
          if (_teamData!.containsKey('members')) {
            final members = _teamData!['members'];
            
            // Map format (most likely)
            if (members is Map) {
              memberIds = members.keys.cast<String>().toList();
            } 
            // List format
            else if (members is List) {
              memberIds = List<String>.from(members);
            }
            
            print('Found ${memberIds.length} members in team data');
          } else {
            print('No members field found in team data');
          }

          if (memberIds.isNotEmpty) {
            // Get team members in batches (Firestore 'whereIn' is limited to 10 items)
            final batches = <List<String>>[];
            for (var i = 0; i < memberIds.length; i += 10) {
              final end = (i + 10 < memberIds.length) ? i + 10 : memberIds.length;
              batches.add(memberIds.sublist(i, end));
            }
            
            final allMemberDocs = <DocumentSnapshot>[];
            for (final batch in batches) {
              final batchSnapshot = await FirebaseFirestore.instance
                  .collection('users')
                  .where(FieldPath.documentId, whereIn: batch)
                  .get();
              allMemberDocs.addAll(batchSnapshot.docs);
            }

            _members = await Future.wait(
              allMemberDocs.map((doc) async {
                final userData = doc.data() as Map<String, dynamic>;
                final isCreator = _teamData?['createdBy'] == doc.id;
                
                // Get task statistics for this member
                final tasksSnapshot = await FirebaseFirestore.instance
                    .collection('tasks')
                    .where('teamId', isEqualTo: _currentTeamId)
                    .where('assignedTo', isEqualTo: doc.id)
                    .get();

                final completedTasks = tasksSnapshot.docs
                    .where((task) => task.data()['status'] == 'done')
                    .length;

                final totalTasks = tasksSnapshot.docs.length;

                return {
                  'id': doc.id,
                  'name': userData['displayName'] ?? userData['name'] ?? 'Unknown',
                  'email': userData['email'] ?? '',
                  'photoURL': userData['photoURL'],
                  'role': isCreator ? 'Team Leader' : 'Team Member',
                  'completedTasks': completedTasks,
                  'totalTasks': totalTasks,
                  'joinedAt': userData['joinedAt'],
                };
              }),
            );
            
            print('Loaded ${_members.length} team members');
          }
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading team info: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Information'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _teamData?['name'] ?? 'Team',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_teamData?['description'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _teamData!['description'],
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.people, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                '${_members.length} Members',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Team Members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._members.map((member) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: member['photoURL'] != null
                            ? ClipOval(
                                child: Image.network(
                                  member['photoURL'],
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                      ),
                      title: Text(
                        member['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member['email']),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: member['role'] == 'Team Leader'
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  member['role'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: member['role'] == 'Team Leader'
                                        ? Colors.amber[800]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${member['completedTasks']}/${member['totalTasks']} tasks',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
    );
  }
} 