import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/utils/navigation_utils.dart';

class DiscussionScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const DiscussionScreen({
    super.key, 
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;
  List<DiscussionPost> _discussions = [];
  String _assignedToUserId = '';
  String? _currentUserName;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUserInfo();
    _loadTaskInfo();
    _markDiscussionsAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _currentUserName = userDoc.data()?['name'] ?? 'Unknown User';
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _loadTaskInfo() async {
    setState(() => _isLoading = true);
    
    try {
      // Check if this is a team chat (main chat)
      final bool isTeamChat = widget.taskId.startsWith('team_');
      
      if (!isTeamChat) {
        // Load task details to get assignedTo user
        final taskDoc = await FirebaseFirestore.instance
            .collection('tasks')
            .doc(widget.taskId)
            .get();
        
        if (taskDoc.exists) {
          final assignedToUserId = taskDoc.data()?['assignedTo'] as String? ?? '';
          setState(() {
            _assignedToUserId = assignedToUserId;
          });
        }
      }
      
      // Load discussions
      await _loadDiscussions();
      
    } catch (e) {
      print('Error loading task info: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadDiscussions() async {
    try {
      // Check if this is a team chat
      final bool isTeamChat = widget.taskId.startsWith('team_');
      final String discussionId = isTeamChat 
          ? widget.taskId  // Use team ID for team chat
          : widget.taskId; // Use task ID for task discussions
      
      final discussionsSnapshot = await FirebaseFirestore.instance
          .collection(isTeamChat ? 'team_discussions' : 'task_discussions')
          .where(isTeamChat ? 'teamId' : 'taskId', isEqualTo: isTeamChat ? widget.taskId.substring(5) : discussionId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final discussions = discussionsSnapshot.docs.map((doc) => 
        DiscussionPost.fromFirestore(doc)
      ).toList();
      
      setState(() {
        _discussions = discussions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading discussions: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _submitPost() async {
    if (_messageController.text.trim().isEmpty) return;
    
    try {
      // Check if this is a team chat
      final bool isTeamChat = widget.taskId.startsWith('team_');
      final String teamId = isTeamChat ? widget.taskId.substring(5) : '';
      
      final post = DiscussionPost(
        id: '',
        taskId: isTeamChat ? '' : widget.taskId,
        teamId: isTeamChat ? teamId : '',
        userId: currentUserId ?? '',
        userName: _currentUserName ?? 'Unknown User',
        content: _messageController.text.trim(),
        createdAt: DateTime.now(),
        likes: [],
      );
      
      // Add post to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection(isTeamChat ? 'team_discussions' : 'task_discussions')
          .add(post.toFirestore());
      
      // Create notification for task owner if not current user and not a team chat
      if (!isTeamChat && _assignedToUserId.isNotEmpty && _assignedToUserId != currentUserId) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': _assignedToUserId,
          'title': 'New Discussion Post',
          'message': '${_currentUserName ?? 'Someone'} added a new idea to task: ${widget.taskTitle}',
          'taskId': widget.taskId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'discussion',
        });
      }
      
      // Clear input and refresh
      _messageController.clear();
      _loadDiscussions();
      
    } catch (e) {
      print('Error submitting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting message: $e')),
        );
      }
    }
  }
  
  Future<void> _likePost(DiscussionPost post) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;
      
      List<String> updatedLikes = List.from(post.likes);
      
      if (post.likes.contains(userId)) {
        // Unlike
        updatedLikes.remove(userId);
      } else {
        // Like
        updatedLikes.add(userId);
      }
      
      // Check if this is a team chat
      final bool isTeamChat = widget.taskId.startsWith('team_');
      
      // Update post in Firestore
      await FirebaseFirestore.instance
          .collection(isTeamChat ? 'team_discussions' : 'task_discussions')
          .doc(post.id)
          .update({
        'likes': updatedLikes,
      });
      
      // Refresh discussions
      _loadDiscussions();
      
    } catch (e) {
      print('Error liking post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: $e')),
        );
      }
    }
  }

  Future<void> _pinMessage(DiscussionPost post) async {
    try {
      // Only allow pinning in team chat
      final bool isTeamChat = widget.taskId.startsWith('team_');
      if (!isTeamChat) return;
      
      // Toggle pin status
      bool isPinned = post.isPinned;
      
      await FirebaseFirestore.instance
          .collection('team_discussions')
          .doc(post.id)
          .update({
        'isPinned': !isPinned,
      });
      
      // Refresh discussions
      _loadDiscussions();
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPinned ? 'Message unpinned' : 'Message pinned'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error pinning message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pinning message: $e')),
        );
      }
    }
  }

  Future<void> _markDiscussionsAsRead() async {
    try {
      if (currentUserId == null) return;
      
      final bool isTeamChat = widget.taskId.startsWith('team_');
      
      // Update lastReadTimestamps for the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({
            'lastReadTimestamps': {
              widget.taskId: FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
          
      print('Marked discussions as read for ${widget.taskId}');
    } catch (e) {
      print('Error marking discussions as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeamChat = widget.taskId.startsWith('team_');
    
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
          title: Text(isTeamChat ? 'Team Chat' : 'Discussion: ${widget.taskTitle}'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Pinned messages section (only for team chat)
                  if (isTeamChat) _buildPinnedMessages(),
                  
                  // Main discussion list
                  Expanded(child: _buildDiscussionList()),
                  
                  // Input section
                  _buildInputSection(),
                  
                  // Extra space to prevent input from being covered by navigation
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
  
  Widget _buildPinnedMessages() {
    // Get pinned messages
    final pinnedMessages = _discussions.where((post) => post.isPinned).toList();
    
    if (pinnedMessages.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.push_pin,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Pinned Messages',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pinnedMessages.map((post) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM d').format(post.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildDiscussionList() {
    if (_discussions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No discussions yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share your thoughts!',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _discussions.length,
      itemBuilder: (context, index) {
        final post = _discussions[index];
        final isCurrentUserPost = post.userId == currentUserId;
        final didCurrentUserLike = post.likes.contains(currentUserId);
        final bool isTeamChat = widget.taskId.startsWith('team_');
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // Highlight pinned messages with a subtle background
          color: post.isPinned ? 
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2) : 
              null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        post.userName.isNotEmpty ? post.userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, y • h:mm a').format(post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (post.isPinned)
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    if (isCurrentUserPost)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(post.content),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Pin button (only for team chat)
                    if (isTeamChat)
                      InkWell(
                        onTap: () => _pinMessage(post),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Icon(
                                post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                size: 18,
                                color: post.isPinned 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post.isPinned ? 'Unpin' : 'Pin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: post.isPinned 
                                      ? Theme.of(context).colorScheme.primary 
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    // Like button
                    InkWell(
                      onTap: () => _likePost(post),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Icon(
                              didCurrentUserLike ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: didCurrentUserLike ? Colors.red : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              post.likes.length.toString(),
                              style: TextStyle(
                                color: didCurrentUserLike ? Colors.red : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
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
  
  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Share your idea or suggestion...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _submitPost,
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class DiscussionPost {
  final String id;
  final String taskId;
  final String teamId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final List<String> likes;
  final bool isPinned;
  
  DiscussionPost({
    required this.id,
    required this.taskId,
    required this.teamId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    required this.likes,
    this.isPinned = false,
  });
  
  factory DiscussionPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiscussionPost(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      teamId: data['teamId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
      isPinned: data['isPinned'] ?? false,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'teamId': teamId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'isPinned': isPinned,
    };
  }
} 