// Application constants for Pro Buddy

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Pro Buddy';
  static const String appVersion = '1.0.0';

  // API Configuration
  // Use reverse proxy domain
  static const String baseUrl = 'https://hawkbuddy.92.5.59.163.sslip.io/api/v1'; 
  static const Duration apiTimeout = Duration(seconds: 60);

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
  static const String onboarding = '$images/onboarding';
  static const String habits = '$images/habits';

  // Specific assets
  static const String logo = '$images/Hawk_logo.png';
  static const String welcomeAnimation = '$animations/welcome.json';
  static const String successAnimation = '$animations/success.json';

  // Onboarding assets
  static const String hawkHero = '$onboarding/hawk_hero.png';

  // Habit card images
  static const String habitDeepWork = '$habits/guy_on_laptop.png';
  static const String habitMorningPlanning = '$habits/open_book_1.png';
  static const String habitWeeklyReview = '$habits/weekly_checklist.png';
  static const String habitPhoneFree = '$habits/locker_pen_phone.png';
  static const String habitNotificationDetox = '$habits/do_not_disturb.png';
  static const String habitJournaling = '$habits/book_pen_blue_towel.png';
  static const String habitEveningShutdown = '$habits/closing_laptop.png';
  static const String habitPomodoro = '$habits/pomodoro.png';
}
