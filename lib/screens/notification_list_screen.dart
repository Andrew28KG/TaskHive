import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:taskhive/screens/bee_detail_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }
  
  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Get notifications for the current user without filtering by read status
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      // Format notifications, handling timestamp issues
      final notifications = notificationsSnapshot.docs.map((doc) {
        final data = doc.data();
        
        // Handle createdAt with fallback to current time if missing
        DateTime createdAt;
        try {
          createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        } catch (e) {
          createdAt = DateTime.now();
        }
        
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Notification',
          'message': data['message'] ?? '',
          'createdAt': createdAt,
          'taskId': data['taskId'],
          'priority': data['priority'] ?? 'worker',
          'isRead': data['isRead'] ?? false,
        };
      }).toList();
      
      // Sort notifications by creation date (newest first)
      notifications.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
      
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
      
      // Mark unread notifications as read
      final unreadNotifications = notificationsSnapshot.docs.where(
        (doc) => doc.data()['isRead'] == false
      ).toList();
      
      if (unreadNotifications.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in unreadNotifications) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
  
  Widget _buildNotificationCard(Map<String, dynamic> notification, bool isDarkMode) {
    final createdAt = notification['createdAt'] as DateTime;
    final priority = notification['priority'] as String;
    final isRead = notification['isRead'] as bool;
    
    Color getPriorityColor() {
      switch (priority.toLowerCase()) {
        case 'queen':
          return Colors.red;
        case 'warrior':
          return Colors.orange;
        case 'worker':
        default:
          return Colors.blue;
      }
    }
    
    return Card(
      elevation: isRead ? 1 : 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: isRead 
          ? null 
          : (isDarkMode ? Colors.grey.shade800 : Colors.blue.shade50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isRead 
            ? BorderSide.none
            : BorderSide(
                color: isDarkMode ? Colors.blue.shade700 : Colors.blue.shade200,
                width: 1,
              ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: getPriorityColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notification_important,
                color: getPriorityColor(),
              ),
            ),
            if (!isRead)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification['message']),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          if (notification['taskId'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BeeDetailScreen(
                  taskId: notification['taskId'],
                ),
              ),
            );
          }
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Refresh Notifications',
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep),
            onPressed: _notifications.isEmpty ? null : _clearAllNotifications,
            tooltip: 'Clear All Notifications',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have no notifications at this time',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(_notifications[index], isDarkMode);
                    },
                  ),
                ),
    );
  }
  
  Future<void> _clearAllNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get all notifications for the current user
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      if (notificationsSnapshot.docs.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Delete all notifications in a batch
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Refresh the list
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing notifications'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
} 