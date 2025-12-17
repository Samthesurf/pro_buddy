// Application constants for Pro Buddy

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Pro Buddy';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator localhost
  static const Duration apiTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String tokenKey = 'firebase_token';
  static const String userIdKey = 'user_id';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String appCacheKey = 'app_classifications_cache';

  // Monitoring Configuration
  static const Duration monitoringInterval = Duration(seconds: 30);
  static const Duration backgroundCheckInterval = Duration(minutes: 15);
  static const Duration appSwitchDebounce = Duration(seconds: 2);

  // Notification Rate Limits
  static const Duration encouragingNotificationCooldown = Duration(hours: 1);
  static const Duration reminderNotificationCooldown = Duration(minutes: 15);

  // Onboarding
  static const int minGoalLength = 10;
  static const int maxAppsToShow = 50;
}

class NotificationChannels {
  NotificationChannels._();

  static const String goalAlignmentId = 'goal_alignment';
  static const String goalAlignmentName = 'Goal Alignment';
  static const String goalAlignmentDescription =
      'Notifications about your app usage and goal alignment';

  static const String monitoringId = 'monitoring';
  static const String monitoringName = 'Usage Monitoring';
  static const String monitoringDescription =
      'Persistent notification for background monitoring';
}

class AssetPaths {
  AssetPaths._();

  static const String images = 'assets/images';
  static const String animations = 'assets/animations';

  // Specific assets
  static const String logo = '$images/Hawk_logo.png';
  static const String welcomeAnimation = '$animations/welcome.json';
  static const String successAnimation = '$animations/success.json';
}
