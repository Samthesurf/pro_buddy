import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification payload types
enum NotificationType {
  usageWarning, // "Is your excessive use of X helping you achieve your goals?"
  goalAligned, // "Seems you are going hard on [goal]!"
  checkIn, // Regular check-in reminder
}

/// Payload data for notification clicks
class NotificationPayload {
  final NotificationType type;
  final String? appName;
  final String? packageName;
  final String? message;

  const NotificationPayload({
    required this.type,
    this.appName,
    this.packageName,
    this.message,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'appName': appName,
    'packageName': packageName,
    'message': message,
  };

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.checkIn,
      ),
      appName: json['appName'] as String?,
      packageName: json['packageName'] as String?,
      message: json['message'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static NotificationPayload? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return NotificationPayload.fromJson(jsonDecode(payload));
    } catch (_) {
      return null;
    }
  }
}

/// Callback type for notification taps
typedef NotificationTapCallback = void Function(NotificationPayload? payload);

/// Service for displaying and handling local notifications
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  NotificationTapCallback? _onTapCallback;
  bool _initialized = false;

  /// Android notification channel IDs
  static const _usageChannelId = 'usage_tracking';
  static const _checkInChannelId = 'check_in';

  /// Initialize the notification service
  Future<void> initialize({NotificationTapCallback? onTap}) async {
    if (_initialized) {
      _onTapCallback = onTap;
      return;
    }

    _onTapCallback = onTap;

    // Initialize timezone data for scheduled notifications
    tz.initializeTimeZones();

    // Android initialization
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    // Create notification channels (Android)
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    _initialized = true;
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // Usage tracking channel (high importance for visibility)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _usageChannelId,
        'Usage Tracking',
        description: 'Notifications about your app usage and goal alignment',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );

    // Check-in reminder channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _checkInChannelId,
        'Check-in Reminders',
        description: 'Reminders to log your daily progress',
        importance: Importance.defaultImportance,
        enableVibration: true,
      ),
    );
  }

  /// Request notification permissions (required on Android 13+)
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true; // Assume enabled on other platforms
  }

  /// Show a usage warning notification
  /// e.g., "Is your excessive use of WhatsApp helping you achieve your goals?"
  Future<void> showUsageWarning({
    required String appName,
    required String packageName,
    required String message,
  }) async {
    final payload = NotificationPayload(
      type: NotificationType.usageWarning,
      appName: appName,
      packageName: packageName,
      message: message,
    );

    await _showNotification(
      id: appName.hashCode,
      title: 'Time Check 🦅',
      body: message,
      channelId: _usageChannelId,
      payload: payload,
    );
  }

  /// Show a goal-aligned notification
  /// e.g., "Seems you are going hard on becoming a software engineer!"
  Future<void> showGoalAligned({required String goal, String? appName}) async {
    final payload = NotificationPayload(
      type: NotificationType.goalAligned,
      appName: appName,
      message: 'Seems you are going hard on $goal!',
    );

    await _showNotification(
      id: goal.hashCode,
      title: 'Keep it up! 🔥',
      body: 'Seems you are going hard on $goal!',
      channelId: _usageChannelId,
      payload: payload,
    );
  }

  /// Show a check-in reminder notification
  Future<void> showCheckInReminder({String? customMessage}) async {
    final payload = NotificationPayload(
      type: NotificationType.checkIn,
      message: customMessage,
    );

    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'How\'s your day going? 📝',
      body:
          customMessage ??
          'Take a moment to log what you\'ve accomplished today.',
      channelId: _checkInChannelId,
      payload: payload,
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required NotificationPayload payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _usageChannelId ? 'Usage Tracking' : 'Check-in Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload.encode());
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload == null) return;

    final payload = NotificationPayload.decode(response.payload);
    if (payload != null && _onTapCallback != null) {
      _onTapCallback!(payload);
    }
  }

  /// Schedule a daily check-in reminder at a specific time
  /// This will trigger even if the app hasn't been opened that day
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? customMessage,
  }) async {
    final payload = NotificationPayload(
      type: NotificationType.checkIn,
      message: customMessage,
    );

    final androidDetails = AndroidNotificationDetails(
      _checkInChannelId,
      'Check-in Reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        customMessage ??
            'Take a moment to log what you\'ve accomplished today.',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Calculate the next occurrence of the scheduled time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReminderNotificationId,
      'How\'s your day going? 📝',
      customMessage ?? 'Take a moment to log what you\'ve accomplished today.',
      scheduledDate,
      details,
      payload: payload.encode(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily!
    );

    // Save the scheduled time for reference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_reminder_hour', hour);
    await prefs.setInt('daily_reminder_minute', minute);

    debugPrint('Daily reminder scheduled for $hour:$minute');
  }

  /// Cancel the scheduled daily reminder
  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderNotificationId);
    debugPrint('Daily reminder cancelled');
  }

  /// Check if daily reminder is scheduled and reschedule if needed
  /// This should be called on app start to ensure notifications persist
  Future<void> ensureDailyReminderScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('daily_reminder_hour');
    final minute = prefs.getInt('daily_reminder_minute');

    if (hour != null && minute != null) {
      await scheduleDailyReminder(hour: hour, minute: minute);
    }
  }

  /// Notification ID for daily reminder (constant so we can update/cancel it)
  static const _dailyReminderNotificationId = 999;

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

/// Background notification handler (must be top-level)
@pragma('vm:entry-point')
void _backgroundHandler(NotificationResponse response) {
  // Background notification responses are handled when app is opened
  // The payload will be processed by the app when it starts
  debugPrint('Background notification tapped: ${response.payload}');
}
