import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app state restoration
/// This helps restore the app to its last state after an abrupt closure
class RestorationService {
  static const String _keyLastRoute = 'restoration_last_route';
  static const String _keyLastRouteArgs = 'restoration_last_route_args';
  static const String _keyIsProperShutdown = 'restoration_is_proper_shutdown';

  /// Save the current route for restoration
  static Future<void> saveRoute(
    String route, {
    Map<String, dynamic>? arguments,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastRoute, route);

      // Mark that the app is running (not properly shut down)
      await prefs.setBool(_keyIsProperShutdown, false);

      // Save route arguments if provided
      if (arguments != null) {
        // Convert map to string for storage
        final argsString = arguments.entries
            .map((e) => '${e.key}:${e.value}')
            .join(',');
        await prefs.setString(_keyLastRouteArgs, argsString);
      } else {
        await prefs.remove(_keyLastRouteArgs);
      }
    } catch (e) {
      print('Error saving route for restoration: $e');
    }
  }

  /// Get the last saved route for restoration
  /// Returns null if this was a proper shutdown or no route was saved
  static Future<String?> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasProperShutdown = prefs.getBool(_keyIsProperShutdown) ?? true;

      // If it was a proper shutdown, don't restore
      if (wasProperShutdown) {
        return null;
      }

      return prefs.getString(_keyLastRoute);
    } catch (e) {
      print('Error getting last route: $e');
      return null;
    }
  }

  /// Get the arguments for the last saved route
  static Future<Map<String, dynamic>?> getLastRouteArguments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final argsString = prefs.getString(_keyLastRouteArgs);

      if (argsString == null || argsString.isEmpty) {
        return null;
      }

      // Parse the arguments string back to a map
      final args = <String, dynamic>{};
      final pairs = argsString.split(',');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final key = parts[0];
          final value = parts[1];
          // Try to parse as bool or keep as string
          if (value == 'true') {
            args[key] = true;
          } else if (value == 'false') {
            args[key] = false;
          } else {
            args[key] = value;
          }
        }
      }

      return args;
    } catch (e) {
      print('Error getting last route arguments: $e');
      return null;
    }
  }

  /// Mark that the app is being properly shut down
  /// This prevents restoration on next launch
  static Future<void> markProperShutdown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsProperShutdown, true);
    } catch (e) {
      print('Error marking proper shutdown: $e');
    }
  }

  /// Clear all restoration data
  static Future<void> clearRestorationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastRoute);
      await prefs.remove(_keyLastRouteArgs);
      await prefs.setBool(_keyIsProperShutdown, true);
    } catch (e) {
      print('Error clearing restoration data: $e');
    }
  }

  /// Check if we should restore state (app was abruptly closed)
  static Future<bool> shouldRestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasProperShutdown = prefs.getBool(_keyIsProperShutdown) ?? true;
      final hasLastRoute = prefs.getString(_keyLastRoute) != null;

      // Only restore if we have a route AND it wasn't a proper shutdown
      return !wasProperShutdown && hasLastRoute;
    } catch (e) {
      print('Error checking if should restore: $e');
      return false;
    }
  }
}
