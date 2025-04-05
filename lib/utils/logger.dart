import 'package:logging/logging.dart';

// Initialize the logger
final Logger logger = Logger('TaskHive');

// Setup function to be called in main.dart
void setupLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // In production, you might want to send logs to a service
    // For now, we'll just print to console in debug mode
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('${record.level.name}: ${record.time}: ${record.message}');
      if (record.error != null) {
        print('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        print('Stack trace: ${record.stackTrace}');
      }
    }
  });
} 