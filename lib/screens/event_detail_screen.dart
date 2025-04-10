import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/main.dart';
import 'package:taskhive/models/event.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taskhive/utils/navigation_utils.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  
  const EventDetailScreen({super.key, required this.eventId});
  
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  Event? _event;
  bool _isCreator = false;
  List<Map<String, dynamic>> _attendees = [];
  String _creatorName = "Unknown";
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadEvent();
  }
  
  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    
    try {
      // Load event data
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      
      if (!eventDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event not found')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      final event = Event.fromFirestore(eventDoc);
      final isCreator = event.createdBy == currentUserId;
      
      // Load attendee data
      final attendees = <Map<String, dynamic>>[];
      
      // Get creator name
      String creatorName = "Unknown";
      try {
        final creatorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(event.createdBy)
            .get();
        
        if (creatorDoc.exists) {
          creatorName = creatorDoc.data()?['name'] ?? 'Unknown User';
        }
      } catch (e) {
        print('Error loading creator info: $e');
      }
      
      // Get attendee details
      for (final userId in event.attendees) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          attendees.add({
            'id': userId,
            'name': userData['name'] ?? 'Unknown User',
            'email': userData['email'] ?? '',
            'isHost': userId == event.createdBy,
          });
        }
      }
      
      // Sort attendees (host first, then alphabetically)
      attendees.sort((a, b) {
        if (a['isHost'] && !b['isHost']) return -1;
        if (!a['isHost'] && b['isHost']) return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });
      
      setState(() {
        _event = event;
        _isCreator = isCreator;
        _attendees = attendees;
        _creatorName = creatorName;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
          title: const Text('Event Details'),
          actions: [
            if (_isCreator && !_isLoading) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editEvent,
                tooltip: 'Edit Event',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _showDeleteConfirmation,
                tooltip: 'Delete Event',
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _event == null
                ? const Center(child: Text('Event not found'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEventHeader(),
                        const SizedBox(height: 24),
                        _buildEventDetails(),
                        const SizedBox(height: 24),
                        _buildAttendeesList(),
                      ],
                    ),
                  ),
      ),
    );
  }
  
  Widget _buildEventHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.deepOrange.shade900, Colors.deepOrange.shade700]
                    : [Colors.orange.shade400, Colors.orange.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _event!.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Text(
                        _creatorName.isNotEmpty ? _creatorName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.deepOrange.shade900 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Organized by $_creatorName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Date and time information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? Colors.grey.shade800 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: isDarkMode
                            ? Colors.deepOrange.shade300
                            : Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d, y').format(_event!.startTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? Colors.grey.shade800 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.access_time,
                        color: isDarkMode
                            ? Colors.deepOrange.shade300
                            : Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: DateFormat('h:mm a').format(_event!.startTime),
                              ),
                              const TextSpan(
                                text: ' - ',
                              ),
                              TextSpan(
                                text: DateFormat('h:mm a').format(_event!.endTime),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventDetails() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate duration correctly
    final startDateTime = _event!.startTime;
    final endDateTime = _event!.endTime;
    
    // Handle case where end time is on the next day (earlier clock time than start)
    final adjustedEndDateTime = endDateTime.isBefore(startDateTime) 
        ? endDateTime.add(const Duration(days: 1)) 
        : endDateTime;
    
    final duration = adjustedEndDateTime.difference(startDateTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    String durationText = '';
    
    if (hours > 0) {
      durationText += '$hours hour${hours > 1 ? 's' : ''} ';
    }
    if (minutes > 0 || hours == 0) {
      durationText += '$minutes minute${minutes != 1 ? 's' : ''}';
    }
    
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
            // Section header
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDarkMode
                      ? Colors.deepOrange.shade300
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Meeting Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Meeting type info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _event!.isOnlineMeeting
                    ? (isDarkMode ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50)
                    : (isDarkMode ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _event!.isOnlineMeeting ? Icons.videocam : Icons.location_on,
                    size: 16,
                    color: _event!.isOnlineMeeting
                        ? (isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700)
                        : (isDarkMode ? Colors.orange.shade300 : Colors.orange.shade700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _event!.isOnlineMeeting ? 'Online Meeting' : 'In-Person Meeting',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _event!.isOnlineMeeting
                          ? (isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700)
                          : (isDarkMode ? Colors.orange.shade300 : Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
            
            // Duration info
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timelapse,
                    size: 16,
                    color: isDarkMode
                        ? Colors.deepOrange.shade300
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: $durationText',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Location or link
            if (_event!.location.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _event!.isOnlineMeeting ? Icons.link : Icons.place,
                          size: 16,
                          color: isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _event!.isOnlineMeeting ? 'Meeting Link:' : 'Location:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _event!.isOnlineMeeting
                        ? InkWell(
                            onTap: () => _launchUrl(_event!.location),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode 
                                    ? Colors.blue.shade900.withOpacity(0.2) 
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDarkMode 
                                      ? Colors.blue.shade700.withOpacity(0.5) 
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _event!.location,
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.open_in_new,
                                    size: 16,
                                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDarkMode 
                                  ? Colors.orange.shade900.withOpacity(0.2) 
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDarkMode 
                                    ? Colors.orange.shade700.withOpacity(0.5) 
                                    : Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(_event!.location),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _openInMaps(_event!.location),
                                  child: Icon(
                                    Icons.map,
                                    size: 16,
                                    color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey.shade800.withOpacity(0.5)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _event!.description.isEmpty 
                    ? 'No description provided' 
                    : _event!.description,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDarkMode
                      ? Colors.grey.shade300
                      : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendeesList() {
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
            // Section header
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: isDarkMode
                      ? Colors.deepOrange.shade300
                      : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Attendees',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.deepOrange.shade900.withOpacity(0.2)
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_attendees.length} people',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.deepOrange.shade300
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _attendees.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No attendees for this event',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attendees.length,
                    separatorBuilder: (context, index) => Divider(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                    ),
                    itemBuilder: (context, index) {
                      final attendee = _attendees[index];
                      final isHost = attendee['isHost'] as bool;
                      
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isHost
                              ? (isDarkMode
                                  ? Colors.deepOrange.shade700
                                  : Colors.orange.shade300)
                              : Theme.of(context).colorScheme.secondary,
                          child: Text(
                            attendee['name'][0].toUpperCase(),
                            style: TextStyle(
                              color: isHost 
                                  ? Colors.white
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                attendee['name'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isHost) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.deepOrange.shade900.withOpacity(0.2)
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.deepOrange.shade300
                                        : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                            // Show "You" if this is the current user
                            if (attendee['id'] == currentUserId) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(attendee['email']),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
  
  void _editEvent() {
    final titleController = TextEditingController(text: _event!.title);
    final descriptionController = TextEditingController(text: _event!.description);
    final locationController = TextEditingController(text: _event!.location);
    
    DateTime selectedDate = DateTime(
      _event!.startTime.year,
      _event!.startTime.month,
      _event!.startTime.day,
    );
    
    TimeOfDay startTime = TimeOfDay(
      hour: _event!.startTime.hour,
      minute: _event!.startTime.minute,
    );
    
    TimeOfDay endTime = TimeOfDay(
      hour: _event!.endTime.hour,
      minute: _event!.endTime.minute,
    );
    
    bool isOnlineMeeting = _event!.isOnlineMeeting;
    List<String> selectedAttendees = List.from(_event!.attendees);
    List<Map<String, dynamic>> teamMembers = [];
    
    // Initialize error message to null
    setState(() {
      _errorMessage = null;
    });
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Meeting'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Meeting Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Error message container
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Meeting Type - Online or Offline
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Meeting Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isOnlineMeeting = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: isOnlineMeeting
                                        ? Theme.of(context).brightness == Brightness.dark
                                            ? Colors.blue.shade800
                                            : Colors.blue.shade100
                                        : Colors.transparent,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.videocam,
                                        color: isOnlineMeeting
                                            ? Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.blue.shade800
                                            : Colors.grey,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Online',
                                        style: TextStyle(
                                          fontWeight: isOnlineMeeting ? FontWeight.bold : FontWeight.normal,
                                          color: isOnlineMeeting
                                              ? Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : Colors.blue.shade800
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isOnlineMeeting = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: !isOnlineMeeting
                                        ? Theme.of(context).brightness == Brightness.dark
                                            ? Colors.orange.shade800
                                            : Colors.orange.shade100
                                        : Colors.transparent,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: !isOnlineMeeting
                                            ? Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.orange.shade800
                                            : Colors.grey,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Offline',
                                        style: TextStyle(
                                          fontWeight: !isOnlineMeeting ? FontWeight.bold : FontWeight.normal,
                                          color: !isOnlineMeeting
                                              ? Theme.of(context).brightness == Brightness.dark
                                                  ? Colors.white
                                                  : Colors.orange.shade800
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location or link field
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: isOnlineMeeting ? 'Meeting Link' : 'Meeting Location',
                      hintText: isOnlineMeeting ? 'https://...' : 'Enter physical location',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(isOnlineMeeting ? Icons.link : Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(
                      DateFormat('MMM d, y').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      
                      if (date != null && mounted) {
                        setState(() {
                          selectedDate = date;
                        });
                      }
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(
                            startTime.format(context),
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            
                            if (time != null && mounted) {
                              // Check if the new start time would make the meeting longer than 5 hours
                              final newStartDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                              
                              final endDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                endTime.hour,
                                endTime.minute,
                              );
                              
                              // Adjust end time if it's earlier than start time (next day)
                              final adjustedEndDateTime = endDateTime.hour < newStartDateTime.hour || 
                                  (endDateTime.hour == newStartDateTime.hour && endDateTime.minute < newStartDateTime.minute)
                                  ? endDateTime.add(const Duration(days: 1))
                                  : endDateTime;
                                  
                              // Calculate duration in minutes
                              final durationMinutes = adjustedEndDateTime.difference(newStartDateTime).inMinutes;
                              
                              if (durationMinutes > 300) { // 5 hours = 300 minutes
                                if (mounted) {
                                  // Show error inside dialog
                                  setState(() {
                                    _errorMessage = 'Meeting duration cannot exceed 5 hours';
                                  });
                                }
                              } else {
                                setState(() {
                                  startTime = time;
                                  _errorMessage = null; // Clear error message
                                });
                              }
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time'),
                          subtitle: Text(
                            endTime.format(context),
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            
                            if (time != null && mounted) {
                              // Check if the new end time would make the meeting longer than 5 hours
                              final startDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                startTime.hour,
                                startTime.minute,
                              );
                              
                              final newEndDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                              
                              // Adjust end time if it's earlier than start time (next day)
                              final adjustedEndDateTime = newEndDateTime.hour < startDateTime.hour || 
                                  (newEndDateTime.hour == startDateTime.hour && newEndDateTime.minute < startDateTime.minute)
                                  ? newEndDateTime.add(const Duration(days: 1))
                                  : newEndDateTime;
                              
                              // Calculate duration in minutes
                              final durationMinutes = adjustedEndDateTime.difference(startDateTime).inMinutes;
                              
                              if (durationMinutes > 300) { // 5 hours = 300 minutes
                                if (mounted) {
                                  // Show error inside dialog
                                  setState(() {
                                    _errorMessage = 'Meeting duration cannot exceed 5 hours';
                                  });
                                }
                              } else {
                                setState(() {
                                  endTime = time;
                                  _errorMessage = null; // Clear error message
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Attendees',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('teams')
                        .doc(_event!.teamId)
                        .get()
                        .then((doc) async {
                          if (!doc.exists) return FirebaseFirestore.instance.collection('users').limit(0).get();
                          
                          final data = doc.data() as Map<String, dynamic>;
                          List<String> memberIds = [];
                          
                          if (data['members'] is List) {
                            memberIds = List<String>.from(data['members']);
                          } else if (data['members'] is Map) {
                            memberIds = (data['members'] as Map).keys.cast<String>().toList();
                          }
                          
                          // Filter out the current user/host
                          memberIds = memberIds.where((id) => id != _event!.createdBy).toList();
                          
                          if (memberIds.isEmpty) return FirebaseFirestore.instance.collection('users').limit(0).get();
                          
                          return FirebaseFirestore.instance
                              .collection('users')
                              .where(FieldPath.documentId, whereIn: memberIds)
                              .get();
                        }),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      
                      final docs = snapshot.data?.docs ?? [];
                      teamMembers = docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return {
                          'id': doc.id,
                          'name': data['name'] ?? 'Unknown User',
                          'email': data['email'] ?? '',
                        };
                      }).toList();
                      
                      if (teamMembers.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('No other team members available'),
                        );
                      }
                      
                      return Column(
                        children: [
                          // Host is automatically included note
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You (admin) will be included automatically',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: teamMembers.every(
                                  (member) => selectedAttendees.contains(member['id']),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      // Add all team members
                                      for (final member in teamMembers) {
                                        if (!selectedAttendees.contains(member['id'])) {
                                          selectedAttendees.add(member['id'] as String);
                                        }
                                      }
                                    } else {
                                      // Remove all except host
                                      selectedAttendees.removeWhere(
                                        (id) => id != _event!.createdBy,
                                      );
                                    }
                                  });
                                },
                              ),
                              const Text('Select All Members'),
                            ],
                          ),
                          const Divider(),
                          ...teamMembers.map((member) {
                            final id = member['id'] as String;
                            return CheckboxListTile(
                              title: Text(member['name'] as String),
                              subtitle: Text(member['email'] as String),
                              value: selectedAttendees.contains(id),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedAttendees.add(id);
                                  } else {
                                    selectedAttendees.remove(id);
                                  }
                                });
                              },
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          }).toList(),
                        ],
                      );
                    },
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
                  if (titleController.text.isEmpty) {
                    // Show error inside the dialog
                    setState(() {
                      _errorMessage = 'Please enter a meeting title';
                    });
                    return;
                  }
                  
                  try {
                    // Create start and end datetimes
                    final startDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      startTime.hour,
                      startTime.minute,
                    );
                    
                    final endDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      endTime.hour,
                      endTime.minute,
                    );
                    
                    // Adjust end time if it's earlier than start time (next day)
                    final adjustedEndDateTime = endDateTime.hour < startDateTime.hour || 
                        (endDateTime.hour == startDateTime.hour && endDateTime.minute < startDateTime.minute)
                        ? endDateTime.add(const Duration(days: 1))
                        : endDateTime;
                    
                    // Verify meeting duration doesn't exceed 5 hours
                    final durationMinutes = adjustedEndDateTime.difference(startDateTime).inMinutes;
                    if (durationMinutes > 300) { // 5 hours = 300 minutes
                      // Show error inside dialog
                      setState(() {
                        _errorMessage = 'Meeting duration cannot exceed 5 hours';
                      });
                      return;
                    }
                    
                    // Always include current user (host) in attendees
                    if (!selectedAttendees.contains(_event!.createdBy)) {
                      selectedAttendees.add(_event!.createdBy);
                    }
                    
                    // Update event in Firestore
                    await FirebaseFirestore.instance
                        .collection('events')
                        .doc(widget.eventId)
                        .update({
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'startTime': Timestamp.fromDate(startDateTime),
                      'endTime': Timestamp.fromDate(adjustedEndDateTime),
                      'attendees': selectedAttendees,
                      'isOnlineMeeting': isOnlineMeeting,
                      'location': locationController.text,
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _loadEvent(); // Reload the event data
                      
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Success'),
                          content: const Text(
                            'Event updated successfully',
                            style: TextStyle(fontSize: 16),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          titleTextStyle: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          contentTextStyle: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Error'),
                          content: Text('Error updating event: ${e.toString()}'),
                          backgroundColor: Theme.of(context).colorScheme.errorContainer,
                          titleTextStyle: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          contentTextStyle: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _launchUrl(String url) async {
    try {
      // Make sure URL starts with http:// or https://
      final String normalizedUrl = url.startsWith('http://') || url.startsWith('https://')
          ? url
          : 'https://$url';
          
      final Uri uri = Uri.parse(normalizedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Error'),
              content: Text('Could not launch $normalizedUrl'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 18,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              contentTextStyle: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Error'),
            content: Text('Invalid URL: $url (Error: $e)'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            contentTextStyle: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _openInMaps(String location) async {
    try {
      final String encodedLocation = Uri.encodeComponent(location);
      final Uri googleMapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');
      
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(
          googleMapsUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Try alternate map URL format
        final Uri alternateUri = Uri.parse('geo:0,0?q=$encodedLocation');
        if (await canLaunchUrl(alternateUri)) {
          await launchUrl(
            alternateUri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          if (mounted) {
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Error'),
                content: Text('Could not open maps for: $location'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                contentTextStyle: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Error'),
            content: Text('Error opening location: $e'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            contentTextStyle: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meeting'),
        content: const Text(
          'Are you sure you want to delete this meeting? This action cannot be undone.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteEvent(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteEvent() async {
    try {
      // Close the confirmation dialog
      Navigator.pop(context);
      
      // Show loading
      setState(() => _isLoading = true);
      
      // Delete the event from Firestore
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .delete();
      
      if (mounted) {
        // Show success message
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Success'),
            content: const Text(
              'Meeting deleted successfully',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 18,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            contentTextStyle: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        // Navigate back to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Error'),
            content: Text('Error deleting meeting: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            contentTextStyle: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
} 