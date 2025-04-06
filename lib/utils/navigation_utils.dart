import 'package:flutter/material.dart';

/// Helper class to handle back navigation consistently throughout the app
class BackNavigationHandler {
  /// Wraps a child widget with a PopScope to handle back button presses
  /// 
  /// If [handleInternalNavigation] is true, the handler will check if there's
  /// internal navigation to handle (e.g., switching to home tab)
  /// 
  /// [onBackPress] is called when the back button is pressed and there's no
  /// internal navigation to handle. It should return true if the back press was
  /// handled, or false to allow the default behavior.
  static Widget wrapWithPopScope({
    required Widget child,
    bool handleInternalNavigation = false,
    bool Function()? onBackPress,
  }) {
    return PopScope(
      canPop: false, // Prevent automatic popping
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        
        // First check custom handler
        if (onBackPress != null && onBackPress()) {
          return;
        }
      },
      child: child,
    );
  }
  
  /// Handles back navigation in the main dashboard, switching to home tab
  /// if on another tab, or showing exit confirmation if on home tab
  static Widget wrapDashboard({
    required Widget child,
    required int selectedIndex,
    required Function(int) onTabChange,
    required BuildContext context,
    required DateTime? lastBackPressTime,
    required Function(DateTime) setLastBackPressTime,
  }) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }

        // If not on home tab, switch to it
        if (selectedIndex != 0) {
          onTabChange(0);
          return;
        }

        // If on home tab, implement double-press-to-exit behavior
        final now = DateTime.now();
        if (lastBackPressTime == null || 
            now.difference(lastBackPressTime) > const Duration(seconds: 2)) {
          setLastBackPressTime(now);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        // If pressed twice within 2 seconds, allow the app to close
        Navigator.of(context).pop();
      },
      child: child,
    );
  }
} 