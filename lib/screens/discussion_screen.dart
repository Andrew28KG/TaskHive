import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/models/bee_task.dart';
import 'package:taskhive/utils/navigation_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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

class _DiscussionScreenState extends State<DiscussionScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  List<DiscussionPost> _discussions = [];
  String _assignedToUserId = '';
  String? _currentUserName;
  File? _selectedImage;
  bool _isUploading = false;
  
  // For highlighting new messages
  String? _highlightedMessageId;
  late AnimationController _highlightAnimationController;
  late Animation<Color?> _highlightAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Set up highlight animation
    _highlightAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _highlightAnimation = ColorTween(
      begin: Colors.yellow.withOpacity(0.3),
      end: Colors.transparent,
    ).animate(_highlightAnimationController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    
    _loadCurrentUserInfo();
    _loadTaskInfo();
    _markDiscussionsAsRead();
    
    // Remove the post-frame callback to avoid competing with _loadDiscussions
    // It will be handled by _loadDiscussions with proper timing
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _highlightAnimationController.dispose();
    super.dispose();
  }

  // Scroll to bottom after new messages are loaded
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      try {
        print('Scrolling to bottom of chat');
        
        // Use a more reliable approach with delayed execution
        // This gives images time to load and layout to complete
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
            
            // Double-check scroll position after a short delay 
            // to ensure we're really at the bottom
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_scrollController.hasClients && 
                  _scrollController.position.pixels != _scrollController.position.maxScrollExtent) {
                _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
              }
            });
          }
        });
      } catch (e) {
        print('Error scrolling to bottom: $e');
        // Fallback with a longer delay if there was an error
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } else {
      print('ScrollController has no clients yet');
    }
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
      
      print('Loading discussions for ${isTeamChat ? "team chat" : "task discussion"}: ${widget.taskId}');
      print('isTeamChat: $isTeamChat');
      
      // For team chat, we need to modify the query
      String teamId = '';
      if (isTeamChat) {
        teamId = widget.taskId.substring(5);
        print('Team ID extracted: $teamId');
      }
      
      // Build the query based on whether it's a team chat or task discussion
      Query query;
      if (isTeamChat) {
        // Temporarily remove the orderBy to avoid requiring a composite index
        query = FirebaseFirestore.instance
            .collection('team_discussions')
            .where('teamId', isEqualTo: teamId);
        
        print('Team chat query with teamId: $teamId');
      } else {
        query = FirebaseFirestore.instance
            .collection('task_discussions')
            .where('taskId', isEqualTo: widget.taskId)
            .orderBy('createdAt', descending: false);
        
        print('Task discussion query with taskId: ${widget.taskId}');
      }
      
      // Add ordering and execute the query
      final discussionsSnapshot = await query.get();
      
      print('Found ${discussionsSnapshot.docs.length} discussions');
      
      // Debug each doc
      discussionsSnapshot.docs.forEach((doc) {
        print('Document ID: ${doc.id}');
        print('Document data: ${doc.data()}');
      });
      
      // For team chat, manually sort the results since we can't use orderBy
      final discussions = discussionsSnapshot.docs.map((doc) { 
        final post = DiscussionPost.fromFirestore(doc);
        print('Discussion: ${post.content} with ID: ${post.id}');
        return post;
      }).toList();
      
      // Sort manually if this is a team chat - ensure oldest messages are at the top
      if (isTeamChat) {
        discussions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      
      setState(() {
        _discussions = discussions;
        _isLoading = false;
      });
      
      print('Set _discussions with ${_discussions.length} messages');
      
      // Use a longer delay for initial load to ensure images have time to load
      if (_discussions.isNotEmpty) {
        // Preload images first (if any) to improve scrolling reliability
        final imageUrls = _discussions
            .where((post) => post.imageUrl != null)
            .map((post) => post.imageUrl!)
            .toList();
            
        if (imageUrls.isNotEmpty) {
          print('Preloading ${imageUrls.length} images before scrolling');
          // Use a longer delay when there are images to load
          Future.delayed(const Duration(milliseconds: 800), _scrollToBottom);
        } else {
          // Use a shorter delay when there are no images
          Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
        }
      }
    } catch (e) {
      print('Error loading discussions: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _pickImage() async {
    try {
      // Check if we're running on an emulator
      bool isEmulator = true;
      try {
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = tempDir.path;
        isEmulator = tempPath.contains('emulator') || tempPath.contains('sdk_gphone');
      } catch (e) {
        print('Error detecting emulator: $e');
      }
      
      if (isEmulator) {
        // Show the simulated dialog for emulators
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Image Selection'),
                content: const Text('This is a simulated image selection for emulator testing. In a real device, this would open the gallery.'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Select Sample Image'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Simulate a successful image selection
                      _handleImageSelection();
                    },
                  ),
                ],
              );
            },
          );
        }
      } else {
        // Real device - use actual image picker
        final ImagePicker picker = ImagePicker();
        
        try {
          final XFile? image = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 70,
          );

          if (image != null) {
            setState(() {
              _selectedImage = File(image.path);
            });
          }
        } catch (e) {
          print('Error picking image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error accessing gallery: $e'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error in image picking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  // Simulate image selection by using a fixed placeholder URL
  void _handleImageSelection() async {
    try {
      setState(() {
        _isUploading = true;
      });
      
      // Show image selection UI
      final placeholderImageOptions = [
        'https://placekitten.com/600/400',
        'https://placedog.net/600/400',
        'https://picsum.photos/600/400'
      ];
      
      // Let user select a placeholder image type
      if (mounted) {
        final selection = await showDialog<int>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Select a sample image'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.pets),
                    title: const Text('Cat image'),
                    onTap: () => Navigator.of(context).pop(0),
                  ),
                  ListTile(
                    leading: const Icon(Icons.pets),
                    title: const Text('Dog image'),
                    onTap: () => Navigator.of(context).pop(1),
                  ),
                  ListTile(
                    leading: const Icon(Icons.image),
                    title: const Text('Random image'),
                    onTap: () => Navigator.of(context).pop(2),
                  ),
                ],
              ),
            );
          },
        );
        
        if (selection == null) {
          setState(() {
            _isUploading = false;
          });
          return; // User cancelled
        }
        
        // Add directly to Firestore with a placeholder image URL
        final bool isTeamChat = widget.taskId.startsWith('team_');
        final String teamId = isTeamChat ? widget.taskId.substring(5) : '';
        
        String imageUrl = placeholderImageOptions[selection];
        // Add a random query parameter to avoid caching
        if (selection == 2) {
          imageUrl += '?random=${DateTime.now().millisecondsSinceEpoch}';
        }

        final post = DiscussionPost(
          id: '',
          taskId: isTeamChat ? '' : widget.taskId,
          teamId: isTeamChat ? teamId : '',
          userId: currentUserId ?? '',
          userName: _currentUserName ?? 'Unknown User',
          content: _messageController.text.trim(),
          createdAt: DateTime.now(),
          likes: [],
          imageUrl: imageUrl,
        );
        
        // Add post to Firestore
        await FirebaseFirestore.instance
            .collection(isTeamChat ? 'team_discussions' : 'task_discussions')
            .add(post.toFirestore());
            
        // Clear input and refresh
        _messageController.clear();
        setState(() {
          _isUploading = false;
        });
        await _loadDiscussions();
        _scrollToBottom();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message with sample image posted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error creating simulated image post: $e');
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().split('Exception:').last.trim()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      // Read the file as bytes
      final bytes = await imageFile.readAsBytes();
      
      // Convert to base64 string
      final String base64Image = base64Encode(bytes);
      
      // Check if the image is not too big (Firestore has a document size limit of 1MB)
      // Compress more if needed
      if (base64Image.length > 500000) {
        // If it's too big, we'll use a placeholder URL instead
        print('Image too large (${base64Image.length} bytes), using placeholder');
        return 'https://picsum.photos/600/400?random=${DateTime.now().millisecondsSinceEpoch}';
      }
      
      print('Successfully encoded image to base64: ${base64Image.length} bytes');
      
      // Return a data URI that can be used directly in an Image widget
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      print('Error encoding image: $e');
      throw Exception('Failed to encode image: $e');
    }
  }

  Future<void> _submitPost() async {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;
    
    try {
      setState(() => _isUploading = true);
      
      // Check if this is a team chat
      final bool isTeamChat = widget.taskId.startsWith('team_');
      final String teamId = isTeamChat ? widget.taskId.substring(5) : '';
      
      String? imageUrl;
      bool hasImage = false;
      
      if (_selectedImage != null) {
        try {
          print('Attempting to upload image file: ${_selectedImage!.path}');
          imageUrl = await _uploadImage(_selectedImage!);
          hasImage = true;
          print('Upload successful. Image URL: $imageUrl');
        } catch (uploadError) {
          print('Image upload error caught in _submitPost: $uploadError');
          // Show error to user but don't continue if image upload failed
          if (mounted) {
            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image upload failed: ${uploadError.toString().split('Exception:').last.trim()}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return; // Exit early without posting
        }
      }
      
      // Only continue if image upload succeeded (or no image was selected)
      // Create the post object
      final post = DiscussionPost(
        id: '',
        taskId: isTeamChat ? '' : widget.taskId,
        teamId: isTeamChat ? teamId : '',
        userId: currentUserId ?? '',
        userName: _currentUserName ?? 'Unknown User',
        content: _messageController.text.trim(),
        createdAt: DateTime.now(),
        likes: [],
        imageUrl: imageUrl,
      );
      
      print('Sending post to Firestore. isTeamChat: $isTeamChat, teamId: $teamId, content: ${post.content}');
      
      // Add post to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection(isTeamChat ? 'team_discussions' : 'task_discussions')
          .add(post.toFirestore());
      
      print('Posted successfully with document ID: ${docRef.id}');
      
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
      
      // Store the image URL for later use with the full screen view
      final String? postedImageUrl = imageUrl;
      
      setState(() {
        _selectedImage = null;
        _isUploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message posted successfully'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Reload discussions
      await _loadDiscussions();
      
      // Get the ID of the newly posted message
      String newPostId = docRef.id;
      
      // Set the highlight with a longer delay to ensure everything has loaded
      Future.delayed(Duration(milliseconds: hasImage ? 800 : 300), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = newPostId;
          });
          
          // Start the highlight animation
          _highlightAnimationController.reset();
          _highlightAnimationController.forward();
          
          // Scroll to the new message with a more reliable approach for images
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
            
            // If the message has an image, show it in full screen after scrolling completes
            if (postedImageUrl != null) {
              Future.delayed(Duration(milliseconds: 800), () {
                if (mounted) {
                  _showFullScreenImage(postedImageUrl, _currentUserName ?? 'You', DateTime.now());
                }
              });
            }
          }
        }
      });
      
    } catch (e) {
      print('Error submitting post: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting message: ${e.toString().split('Exception:').last.trim()}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _submitPost(),
            ),
          ),
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

  Future<void> _deleteMessage(DiscussionPost post) async {
    try {
      // Only allow users to delete their own messages
      if (post.userId != currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can only delete your own messages')),
          );
        }
        return;
      }
      
      // Confirm deletion
      final bool confirmDelete = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirmDelete) return;
      
      // Check if this is a team chat
      final bool isTeamChat = widget.taskId.startsWith('team_');
      
      // Delete the message from appropriate collection
      await FirebaseFirestore.instance
          .collection(isTeamChat ? 'team_discussions' : 'task_discussions')
          .doc(post.id)
          .delete();
      
      // Refresh discussions
      _loadDiscussions();
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e')),
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
          actions: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              tooltip: 'View Images',
              onPressed: _showImagesGallery,
            ),
          ],
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
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _discussions.length,
      itemBuilder: (context, index) {
        final post = _discussions[index];
        final isCurrentUserPost = post.userId == currentUserId;
        final didCurrentUserLike = post.likes.contains(currentUserId);
        final bool isTeamChat = widget.taskId.startsWith('team_');
        final bool isHighlighted = _highlightedMessageId == post.id;
        
        return AnimatedBuilder(
          animation: _highlightAnimationController,
          builder: (context, child) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: isHighlighted ? 3 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              // Highlight color based on pinned status or animation
              color: isHighlighted 
                  ? _highlightAnimation.value 
                  : (post.isPinned 
                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2) 
                      : null),
              child: child,
            );
          },
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
                    // Action buttons
                    if (isCurrentUserPost) 
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => _deleteMessage(post),
                        tooltip: 'Delete message',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                      ),
                    const SizedBox(width: 4),
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
                if (post.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () => _showFullScreenImage(post.imageUrl!, post.userName, post.createdAt),
                      child: Stack(
                        children: [
                          Hero(
                            tag: 'image_${post.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: post.imageUrl!.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(post.imageUrl!.split(',')[1]),
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    cacheHeight: 400,
                                    gaplessPlayback: true,
                                  )
                                : Image.network(
                                  post.imageUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  cacheWidth: 800,
                                  gaplessPlayback: true,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    
                                    return Stack(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          height: 200,
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.image,
                                            size: 50,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading image: $error');
                                    return Container(
                                      width: double.infinity,
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                              size: 30,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Image failed to load',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (post.content.isNotEmpty) Text(post.content),
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
      child: Column(
        children: [
          if (_selectedImage != null)
            Stack(
              children: [
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _isUploading ? null : _pickImage,
                icon: Icon(
                  Icons.image,
                  color: _isUploading 
                      ? Colors.grey 
                      : Theme.of(context).brightness == Brightness.dark 
                          ? Colors.lightBlue[300] 
                          : Theme.of(context).primaryColor,
                ),
              ),
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
              _isUploading
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(),
                    )
                  : FloatingActionButton(
                      onPressed: _submitPost,
                      mini: true,
                      child: const Icon(Icons.send),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImagesGallery() {
    // Get all messages with images
    final messagesWithImages = _discussions.where((post) => post.imageUrl != null).toList();
    
    if (messagesWithImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No images found in this conversation'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(
                        'Photo Album (${messagesWithImages.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: messagesWithImages.length,
                    itemBuilder: (context, index) {
                      final post = messagesWithImages[index];
                      return GestureDetector(
                        onTap: () => _showFullScreenImage(post.imageUrl!, post.userName, post.createdAt),
                        child: Hero(
                          tag: 'image_${post.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: post.imageUrl!.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(post.imageUrl!.split(',')[1]),
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  post.imageUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading image: $error');
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.error, color: Colors.red),
                                    );
                                  },
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _showFullScreenImage(String imageUrl, String userName, DateTime timestamp) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(userName),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(timestamp),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share functionality would go here')),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(80),
                minScale: 0.5,
                maxScale: 4,
                child: imageUrl.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(imageUrl.split(',')[1]),
                    )
                  : Image.network(
                      imageUrl,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 30,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Image failed to load',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
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
  final String? imageUrl;
  
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
    this.imageUrl,
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
      imageUrl: data['imageUrl'],
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
      'imageUrl': imageUrl,
    };
  }
} 