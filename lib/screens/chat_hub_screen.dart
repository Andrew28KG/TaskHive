import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/screens/discussion_screen.dart';
import 'package:taskhive/utils/navigation_utils.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  bool _isLoading = true;
  List<TaskDiscussionInfo> _taskDiscussions = [];
  String? _currentTeamId;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, List<TaskDiscussionInfo>> _tasksByHive = {};
  List<String> _pinnedTaskIds = [];
  final int _maxPinnedChats = 3;
  
  @override
  void initState() {
    super.initState();
    _loadTeamData();
    _loadPinnedChats();
  }
  
  Future<void> _loadTeamData() async {
    try {
      setState(() => _isLoading = true);
      
      // Get current team ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
          
      final teamId = userDoc.data()?['currentTeamId'] as String?;
      
      if (teamId == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No team selected. Please select a team first.';
        });
        return;
      }
      
      setState(() => _currentTeamId = teamId);
      
      // Load tasks
      await _loadTaskDiscussions();
      
    } catch (e) {
      print('Error loading team data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error loading team data: $e';
      });
    }
  }
  
  Future<void> _loadTaskDiscussions() async {
    try {
      if (_currentTeamId == null) return;
      
      // Get tasks for the current team
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('teamId', isEqualTo: _currentTeamId)
          .get();
          
      final List<TaskDiscussionInfo> taskDiscussions = [];
      final Map<String, List<TaskDiscussionInfo>> tasksByHive = {};
      
      // Get last read timestamps for the current user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      Map<String, dynamic> lastReadTimestamps = {};
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['lastReadTimestamps'] is Map) {
          lastReadTimestamps = Map<String, dynamic>.from(userData['lastReadTimestamps']);
        }
      }
      
      // For each task, check if it has discussions
      for (final taskDoc in tasksSnapshot.docs) {
        final taskId = taskDoc.id;
        final taskData = taskDoc.data();
        
        // Get discussions count
        final discussionsSnapshot = await FirebaseFirestore.instance
            .collection('task_discussions')
            .where('taskId', isEqualTo: taskId)
            .count()
            .get();
            
        final discussionCount = discussionsSnapshot.count ?? 0;
        
        // Get the most recent discussion timestamp
        DateTime? lastActivityTime;
        int unreadCount = 0;
        
        if (discussionCount > 0) {
          // Get all discussions
          final discussionsQuery = await FirebaseFirestore.instance
              .collection('task_discussions')
              .where('taskId', isEqualTo: taskId)
              .orderBy('createdAt', descending: true)
              .get();
              
          if (discussionsQuery.docs.isNotEmpty) {
            final latestDiscussion = discussionsQuery.docs.first.data();
            lastActivityTime = (latestDiscussion['createdAt'] as Timestamp).toDate();
            
            // Get last read timestamp for this task
            final lastReadTimestamp = lastReadTimestamps[taskId] != null 
                ? (lastReadTimestamps[taskId] as Timestamp).toDate() 
                : DateTime(2000); // Default old date if never read
            
            // Count unread messages
            unreadCount = discussionsQuery.docs
                .where((doc) {
                  final msgTime = (doc.data()['createdAt'] as Timestamp).toDate();
                  return msgTime.isAfter(lastReadTimestamp);
                })
                .length;
          }
        }
        
        // Get assigned user info
        String assignedUserName = 'Unassigned';
        final assignedUserId = taskData['assignedTo'] as String?;
        if (assignedUserId != null && assignedUserId.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(assignedUserId)
              .get();
              
          if (userDoc.exists) {
            assignedUserName = userDoc.data()?['name'] ?? 'Unknown User';
          }
        }
        
        // Get hive/project info
        final hiveId = taskData['hiveId'] as String? ?? '';
        String hiveName = 'General';
        
        if (hiveId.isNotEmpty) {
          final hiveDoc = await FirebaseFirestore.instance
              .collection('projects')
              .doc(hiveId)
              .get();
              
          if (hiveDoc.exists) {
            hiveName = hiveDoc.data()?['name'] ?? 'Unknown Hive';
          }
        }
        
        // Create task info object
        final taskInfo = TaskDiscussionInfo(
          taskId: taskId,
          taskTitle: taskData['title'] ?? 'Untitled Task',
          discussionCount: discussionCount,
          unreadCount: unreadCount,
          lastActivityTime: lastActivityTime,
          assignedUserName: assignedUserName,
          assignedUserId: assignedUserId ?? '',
          status: taskData['status'] ?? 'todo',
          hiveName: hiveName,
          hiveId: hiveId.isEmpty ? '_general' : hiveId, // Use '_general' for tasks without a hive
        );
        
        // Add this task to the list if it has discussions or is not completed
        if (discussionCount > 0 || taskData['status'] != 'done') {
          taskDiscussions.add(taskInfo);
          
          // Group by hive
          if (!tasksByHive.containsKey(taskInfo.hiveId)) {
            tasksByHive[taskInfo.hiveId] = [];
          }
          tasksByHive[taskInfo.hiveId]!.add(taskInfo);
        }
      }
      
      // Handle team chat
      int teamChatUnreadCount = 0;
      DateTime? teamChatLastActivity;
      
      // Get team discussions
      final teamId = _currentTeamId;
      if (teamId != null) {
        // Get last read timestamp for team chat
        final teamChatId = 'team_$teamId';
        final lastReadTimestamp = lastReadTimestamps[teamChatId] != null 
            ? (lastReadTimestamps[teamChatId] as Timestamp).toDate() 
            : DateTime(2000); // Default old date if never read
        
        final teamDiscussionsQuery = await FirebaseFirestore.instance
            .collection('team_discussions')
            .where('teamId', isEqualTo: teamId)
            .orderBy('createdAt', descending: true)
            .get();
            
        if (teamDiscussionsQuery.docs.isNotEmpty) {
          teamChatLastActivity = (teamDiscussionsQuery.docs.first.data()['createdAt'] as Timestamp).toDate();
          
          // Count unread messages
          teamChatUnreadCount = teamDiscussionsQuery.docs
              .where((doc) {
                final msgTime = (doc.data()['createdAt'] as Timestamp).toDate();
                return msgTime.isAfter(lastReadTimestamp);
              })
              .length;
        }
      }
      
      // Create a general/team-wide chat entry for the main chat
      final mainChatInfo = TaskDiscussionInfo(
        taskId: 'team_${_currentTeamId}',
        taskTitle: 'Team Chat',
        discussionCount: 0, // Not used for display
        unreadCount: teamChatUnreadCount,
        lastActivityTime: teamChatLastActivity,
        assignedUserName: '',
        assignedUserId: '',
        status: 'main',
        hiveName: 'Main Chat',
        hiveId: '_main',
      );
      
      // Add the main chat to the list
      taskDiscussions.insert(0, mainChatInfo);
      
      // Also add to tasksByHive
      tasksByHive['_main'] = [mainChatInfo];
      
      // Sort tasks within each hive by last activity time (most recent first)
      tasksByHive.forEach((hiveId, tasks) {
        tasks.sort((a, b) {
          if (a.lastActivityTime == null && b.lastActivityTime == null) {
            return 0;
          } else if (a.lastActivityTime == null) {
            return 1;
          } else if (b.lastActivityTime == null) {
            return -1;
          } else {
            return b.lastActivityTime!.compareTo(a.lastActivityTime!);
          }
        });
      });
      
      setState(() {
        _taskDiscussions = taskDiscussions;
        _tasksByHive = tasksByHive;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading task discussions: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error loading discussions: $e';
      });
    }
  }
  
  Future<void> _loadPinnedChats() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['pinnedChats'] is List) {
          setState(() {
            _pinnedTaskIds = List<String>.from(userData['pinnedChats']);
          });
        }
      }
    } catch (e) {
      print('Error loading pinned chats: $e');
    }
  }
  
  Future<void> _togglePinChat(String taskId) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);
      
      // If already pinned, unpin it
      if (_pinnedTaskIds.contains(taskId)) {
        await userRef.update({
          'pinnedChats': FieldValue.arrayRemove([taskId])
        });
        
        setState(() {
          _pinnedTaskIds.remove(taskId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat unpinned'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } 
      // If not pinned and haven't reached max, pin it
      else if (_pinnedTaskIds.length < _maxPinnedChats) {
        await userRef.update({
          'pinnedChats': FieldValue.arrayUnion([taskId])
        });
        
        setState(() {
          _pinnedTaskIds.add(taskId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat pinned'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } 
      // If reached max pinned chats
      else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can only pin up to $_maxPinnedChats chats'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error toggling pinned chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating pinned chat: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        // Return to home tab when back is pressed
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[400],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadTeamData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Chat Header
                      SliverAppBar(
                        expandedHeight: 80,
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.deepOrange.shade900
                          : Colors.orange.shade400,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            'Team Chat',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          centerTitle: true,
                        ),
                      ),
                      _buildPinnedChats(),
                      _buildTeamChat(),
                      _buildGroupedChats(),
                    ],
                  ),
      ),
    );
  }
  
  Widget _buildPinnedChats() {
    // Get pinned tasks
    final pinnedTasks = _taskDiscussions
      .where((task) => _pinnedTaskIds.contains(task.taskId) && task.status != 'main')
      .toList();
      
    if (pinnedTasks.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  size: 16,
                  color: Colors.blue[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Pinned Chats',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ...pinnedTasks.map((task) => _buildSimplifiedTaskDiscussionItem(task)),
        ],
      ),
    );
  }
  
  Widget _buildTeamChat() {
    // Find the team chat entry
    final teamChat = _taskDiscussions.firstWhere(
      (task) => task.hiveId == '_main',
      orElse: () => TaskDiscussionInfo(
        taskId: 'team_${_currentTeamId}',
        taskTitle: 'Team Chat',
        discussionCount: 0,
        unreadCount: 0,
        lastActivityTime: null,
        assignedUserName: '',
        assignedUserId: '',
        status: 'main',
        hiveName: 'Main Chat',
        hiveId: '_main',
      ),
    );
    
    if (teamChat.taskId.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people_alt,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Team Communication Hub',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [Colors.deepOrange.shade900, Colors.orange.shade800]
                    : [Colors.orange.shade100, Colors.deepOrange.shade200],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(isDarkMode ? 0.3 : 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiscussionScreen(
                      taskId: teamChat.taskId,
                      taskTitle: teamChat.taskTitle,
                    ),
                  ),
                ).then((_) => _loadTaskDiscussions());
              },
              onLongPress: () => _showChatOptions(teamChat),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.deepOrange.shade700 : Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.forum_rounded,
                            size: 24,
                            color: isDarkMode ? Colors.white : Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teamChat.taskTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDarkMode ? Colors.white : Colors.deepOrange.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Collaborate with your entire team',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white70 : Colors.deepOrange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (teamChat.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mark_chat_unread,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  teamChat.unreadCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.deepOrange.shade700.withOpacity(0.7) : Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.message_rounded,
                                size: 14,
                                color: isDarkMode ? Colors.white70 : Colors.deepOrange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to open',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white70 : Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (teamChat.lastActivityTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.deepOrange.shade700.withOpacity(0.7) : Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.deepOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDateTime(teamChat.lastActivityTime!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white70 : Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
        ],
      ),
    );
  }
  
  Widget _buildGroupedChats() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = _tasksByHive.entries.where((e) => e.key != '_main').toList()[index];
          final hiveId = entry.key;
          final tasks = entry.value;
          
          // Skip empty hives
          if (tasks.isEmpty) return const SizedBox.shrink();
          
          // Get hive name
          String hiveName = tasks.first.hiveName;
          if (hiveId == '_general') hiveName = 'General';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      hiveId == '_general' ? Icons.chat : Icons.hive,
                      size: 16,
                      color: hiveId == '_general' ? Colors.grey[600] : Colors.amber[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hiveName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hiveId == '_general' ? Colors.grey[800] : Colors.amber[800],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ...tasks
                  // Filter out pinned tasks since they're already shown
                  .where((task) => !_pinnedTaskIds.contains(task.taskId))
                  .map((task) => _buildSimplifiedTaskDiscussionItem(task)),
            ],
          );
        },
        childCount: _tasksByHive.entries.where((e) => e.key != '_main').length,
      ),
    );
  }
  
  Widget _buildSimplifiedTaskDiscussionItem(TaskDiscussionInfo taskInfo) {
    final statusColor = _getStatusColor(taskInfo.status);
    final isPinned = _pinnedTaskIds.contains(taskInfo.taskId);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // Highlight pinned chats
      color: isPinned 
          ? (Theme.of(context).brightness == Brightness.dark 
              ? Colors.blue.shade900.withOpacity(0.2) 
              : Colors.blue.shade50)
          : null,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiscussionScreen(
                taskId: taskInfo.taskId,
                taskTitle: taskInfo.taskTitle,
              ),
            ),
          ).then((_) => _loadTaskDiscussions());
        },
        onLongPress: () => _showChatOptions(taskInfo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Task status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Task title
                  Expanded(
                    child: Text(
                      taskInfo.taskTitle,
                      style: TextStyle(
                        fontWeight: isPinned ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Pin icon
                  if (isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Colors.blue[400],
                      ),
                    ),
                  // Unread count - only show if there are unread messages
                  if (taskInfo.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mark_chat_unread,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            taskInfo.unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // Last activity time
              if (taskInfo.lastActivityTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Last activity: ${_formatDateTime(taskInfo.lastActivityTime!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  void _showChatOptions(TaskDiscussionInfo taskInfo) {
    final isPinned = _pinnedTaskIds.contains(taskInfo.taskId);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: isPinned ? Colors.grey : Colors.blue,
              ),
              title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
              subtitle: isPinned 
                  ? const Text('Remove from pinned chats')
                  : Text(_pinnedTaskIds.length >= _maxPinnedChats 
                      ? 'Maximum of $_maxPinnedChats chats can be pinned' 
                      : 'Add to pinned chats for quick access'),
              onTap: () {
                Navigator.pop(context);
                _togglePinChat(taskInfo.taskId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open Discussion'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiscussionScreen(
                      taskId: taskInfo.taskId,
                      taskTitle: taskInfo.taskTitle,
                    ),
                  ),
                ).then((_) => _loadTaskDiscussions());
              },
            ),
            ListTile(
              leading: const Icon(Icons.task),
              title: const Text('View Task Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/task',
                  arguments: taskInfo.taskId,
                ).then((_) => _loadTaskDiscussions());
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'todo':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        } else {
          return '${difference.inMinutes} min ago';
        }
      } else {
        return '${difference.inHours} hours ago';
      }
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }
}

class TaskDiscussionInfo {
  final String taskId;
  final String taskTitle;
  final int discussionCount;
  final int unreadCount;
  final DateTime? lastActivityTime;
  final String assignedUserName;
  final String assignedUserId;
  final String status;
  final String hiveName;
  final String hiveId;
  
  TaskDiscussionInfo({
    required this.taskId,
    required this.taskTitle,
    required this.discussionCount,
    required this.unreadCount,
    required this.lastActivityTime,
    required this.assignedUserName,
    required this.assignedUserId,
    required this.status,
    required this.hiveName,
    required this.hiveId,
  });
} 