import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/screens/auth/login_screen.dart';
import 'package:taskhive/screens/auth/register_screen.dart';
import 'package:taskhive/screens/dashboard_screen.dart';
import 'package:taskhive/screens/hive_detail_screen.dart';
import 'package:taskhive/screens/bee_detail_screen.dart';
import 'package:taskhive/screens/event_detail_screen.dart';
import 'package:taskhive/screens/calendar_screen.dart';
import 'package:taskhive/screens/focus_screen.dart';
import 'package:taskhive/screens/profile_screen.dart';
import 'package:taskhive/screens/onboarding_screen.dart';
import 'package:taskhive/screens/team_screen.dart';
import 'package:taskhive/screens/collaboration_screen.dart';
import 'package:taskhive/screens/analytics_screen.dart';
import 'package:taskhive/screens/progress_screen.dart';
import 'package:taskhive/screens/progress_detail_screen.dart';
import 'package:taskhive/theme/app_theme.dart';
import 'package:taskhive/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskhive/utils/tutorial_manager.dart';

// Global variable to store the current user ID
String? currentUserId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger
  setupLogger();
  
  // Load initial theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  
  try {
    await Firebase.initializeApp();
    logger.info('Firebase initialized successfully');
    
    // Connect to Firebase emulators for development
    if (const bool.fromEnvironment('USE_FIREBASE_EMU')) {
      FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      logger.info('Connected to Firebase emulators');
    }
    
    // For development: sign out when restarting the app to force login
    await FirebaseAuth.instance.signOut();
    
    // Reset onboarding and tutorials for testing
    await prefs.setBool('hasSeenOnboarding', false);
    await TutorialManager.resetAllTutorials();
    
    // Set current user ID if already logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      logger.info('User already logged in: $currentUserId');
    }

  } catch (e) {
    logger.severe('Error initializing Firebase', e);
  }
  
  runApp(TaskHiveApp(
    isDarkMode: isDarkMode,
    hasSeenOnboarding: hasSeenOnboarding,
  ));
}

class TaskHiveApp extends StatefulWidget {
  final bool isDarkMode;
  final bool hasSeenOnboarding;
  
  const TaskHiveApp({
    super.key,
    required this.isDarkMode,
    required this.hasSeenOnboarding,
  });

  @override
  State<TaskHiveApp> createState() => _TaskHiveAppState();
  
  // Add static method to access state
  static _TaskHiveAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_TaskHiveAppState>();
  }
}

class _TaskHiveAppState extends State<TaskHiveApp> {
  bool _isDarkMode = false;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    
    // Listen for auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        currentUserId = user.uid;
        logger.info('Auth state changed - User logged in: $currentUserId');
      } else {
        currentUserId = null;
        logger.info('Auth state changed - User logged out');
      }
    });
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  bool _hasTeam(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    return userData.containsKey('currentTeamId') &&
           userData['currentTeamId'] != null &&
           userData['currentTeamId'] != '';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskHive',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // Check onboarding and authentication state
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Show onboarding for first-time users
          if (!widget.hasSeenOnboarding) {
            return const OnboardingScreen();
          }
          
          // If not logged in, show login screen
          if (!snapshot.hasData) {
            return const LoginScreen();
          }
          
          // Check if user has a team
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // If user has no team, show team management
              if (!userSnapshot.hasData || 
                  !(userSnapshot.data!.exists) ||
                  !_hasTeam(userSnapshot.data!.data() as Map<String, dynamic>?)) {
                return const TeamScreen();
              }
              
              // Otherwise, show dashboard
              return const DashboardScreen();
            },
          );
        },
      ),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/team': (context) => const TeamScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/progress': (context) => const ProgressScreen(),
        '/focus': (context) => const FocusScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/collaboration': (context) => const CollaborationScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/project') {
          final projectId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => HiveDetailScreen(projectId: projectId),
          );
        }
        
        if (settings.name == '/task') {
          final taskId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => BeeDetailScreen(taskId: taskId),
          );
        }

        if (settings.name == '/event') {
          final eventId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => EventDetailScreen(eventId: eventId),
          );
        }

        if (settings.name == '/progress-detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ProgressDetailScreen(
              hiveId: args['hiveId'],
              hiveName: args['hiveName'],
              isTeamCreator: args['isTeamCreator'],
            ),
          );
        }
        
        return null;
      },
    );
  }
}
