import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
