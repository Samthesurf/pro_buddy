import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'api_service.dart';
import 'notification_service.dart';
import 'usage_tracking_service.dart';

/// Task identifiers for WorkManager
const String usageCheckTask = 'com.example.pro_buddy.usageCheck';
const String periodicUsageCheckTask =
    'com.example.pro_buddy.periodicUsageCheck';

/// Background service for periodic app usage checks
class BackgroundService {
  static BackgroundService? _instance;
  static BackgroundService get instance {
    _instance ??= BackgroundService._();
    return _instance!;
  }

  BackgroundService._();

  bool _initialized = false;

  /// Initialize WorkManager and register background tasks
  Future<void> initialize() async {
    if (_initialized) return;

    await Workmanager().initialize(backgroundTaskCallback);

    _initialized = true;
  }

  /// Register periodic background task for usage checking
  /// Runs every 15 minutes (minimum allowed by Android WorkManager)
  Future<void> registerPeriodicUsageCheck() async {
    await Workmanager().registerPeriodicTask(
      periodicUsageCheckTask,
      periodicUsageCheckTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }

  /// Trigger an immediate usage check (for testing)
  Future<void> triggerImmediateCheck() async {
    await Workmanager().registerOneOffTask(
      '${usageCheckTask}_${DateTime.now().millisecondsSinceEpoch}',
      usageCheckTask,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

/// Top-level callback function for WorkManager
/// This must be a top-level function (not a class method)
@pragma('vm:entry-point')
void backgroundTaskCallback() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      debugPrint('Background task started: $taskName');

      if (taskName == usageCheckTask || taskName == periodicUsageCheckTask) {
        // Run both checks
        await Future.wait([
          _performUsageCheck(),
          _checkDailyReminder(),
        ]);
      }

      return true;
    } catch (e) {
      debugPrint('Background task error: $e');
      return false;
    }
  });
}

/// Check if we need to send a daily reminder (after 8 PM)
Future<void> _checkDailyReminder() async {
  try {
    final now = DateTime.now();
    // Target time: 8:00 PM (20:00)
    if (now.hour < 20) return;

    final prefs = await SharedPreferences.getInstance();
    const key = 'last_check_in_reminder_date';
    final lastDateStr = prefs.getString(key);
    
    final todayStr = "${now.year}-${now.month}-${now.day}";
    
    if (lastDateStr == todayStr) {
      return; // Already sent today
    }

    // Initialize notification service
    await NotificationService.instance.initialize();
    await NotificationService.instance.showCheckInReminder();

    await prefs.setString(key, todayStr);
    debugPrint('Daily check-in reminder sent');
  } catch (e) {
    debugPrint('Error in daily reminder check: $e');
  }
}

/// Perform the actual usage check logic
Future<void> _performUsageCheck() async {
  final usageService = UsageTrackingService.instance;

  // Check if we have permission
  final hasPermission = await usageService.hasUsageStatsPermission();
  if (!hasPermission) {
    debugPrint('No usage stats permission, skipping check');
    return;
  }

  // Get high usage apps (more than 30 minutes today)
  final highUsageApps = await usageService.getHighUsageApps(
    threshold: const Duration(minutes: 30),
  );

  if (highUsageApps.isEmpty) {
    debugPrint('No high usage apps found');
    return;
  }

  // Process each high usage app
  for (final app in highUsageApps.take(3)) {
    try {
      // Report to backend for AI analysis
      final response = await ApiService.instance.reportAppUsage(
        packageName: app.packageName,
        appName: app.appName,
      );

      final shouldNotify = response['should_notify'] as bool? ?? false;
      final message = response['message'] as String?;
      final alignmentStatus = response['alignment_status'] as String?;

      if (shouldNotify && message != null) {
        // Initialize notification service
        await NotificationService.instance.initialize();

        if (alignmentStatus == 'misaligned') {
          // Show usage warning notification
          await NotificationService.instance.showUsageWarning(
            appName: app.appName,
            packageName: app.packageName,
            message: message,
          );
        } else if (alignmentStatus == 'aligned') {
          // Show encouragement notification
          final goal = response['primary_goal'] as String?;
          if (goal != null) {
            await NotificationService.instance.showGoalAligned(
              goal: goal,
              appName: app.appName,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error reporting app usage: $e');
    }
  }
}
