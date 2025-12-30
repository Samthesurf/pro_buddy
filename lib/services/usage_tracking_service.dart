import 'package:flutter/services.dart';

/// Model representing app usage statistics
class AppUsageStat {
  final String packageName;
  final String appName;
  final Duration usageTime;
  final DateTime lastUsed;

  const AppUsageStat({
    required this.packageName,
    required this.appName,
    required this.usageTime,
    required this.lastUsed,
  });

  factory AppUsageStat.fromMap(Map<String, dynamic> map) {
    return AppUsageStat(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      usageTime: Duration(milliseconds: map['usageTimeMs'] as int),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(map['lastTimeUsed'] as int),
    );
  }

  Map<String, dynamic> toJson() => {
    'package_name': packageName,
    'app_name': appName,
    'usage_time_ms': usageTime.inMilliseconds,
    'last_used': lastUsed.toIso8601String(),
  };

  String get formattedUsageTime {
    final hours = usageTime.inHours;
    final minutes = usageTime.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '< 1m';
    }
  }

  @override
  String toString() => 'AppUsageStat($appName: ${formattedUsageTime})';
}

/// Service for tracking app usage via Android UsageStatsManager
class UsageTrackingService {
  static const _channel = MethodChannel('com.example.pro_buddy/usage_stats');

  static UsageTrackingService? _instance;
  static UsageTrackingService get instance {
    _instance ??= UsageTrackingService._();
    return _instance!;
  }

  UsageTrackingService._();

  /// Check if the app has permission to access usage stats
  Future<bool> hasUsageStatsPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'hasUsageStatsPermission',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error checking usage stats permission: $e');
      return false;
    }
  }

  /// Open the system settings page for granting usage stats access
  Future<bool> openUsageStatsSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openUsageStatsSettings',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error opening usage stats settings: $e');
      return false;
    }
  }

  /// Get usage stats for the specified duration (in minutes)
  /// Returns a list of AppUsageStat sorted by usage time descending
  Future<List<AppUsageStat>> getUsageStats({int durationMinutes = 60}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getUsageStats',
        {'durationMinutes': durationMinutes},
      );

      if (result == null) return [];

      return result
          .map(
            (item) =>
                AppUsageStat.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on PlatformException catch (e) {
      print('Error getting usage stats: $e');
      return [];
    }
  }

  /// Get today's usage stats
  Future<List<AppUsageStat>> getDailyUsageStats() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getDailyUsageStats',
      );

      if (result == null) return [];

      return result
          .map(
            (item) =>
                AppUsageStat.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on PlatformException catch (e) {
      print('Error getting daily usage stats: $e');
      return [];
    }
  }

  /// Get the top N apps by usage time today
  Future<List<AppUsageStat>> getTopAppsToday({int limit = 5}) async {
    final stats = await getDailyUsageStats();
    return stats.take(limit).toList();
  }

  /// Get total screen time today
  Future<Duration> getTotalScreenTimeToday() async {
    final stats = await getDailyUsageStats();
    final totalMs = stats.fold<int>(
      0,
      (sum, stat) => sum + stat.usageTime.inMilliseconds,
    );
    return Duration(milliseconds: totalMs);
  }

  /// Get apps that have been used for more than the threshold
  Future<List<AppUsageStat>> getHighUsageApps({
    Duration threshold = const Duration(minutes: 30),
  }) async {
    final stats = await getDailyUsageStats();
    return stats.where((s) => s.usageTime >= threshold).toList();
  }

  /// Format total screen time as human-readable string
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '< 1m';
    }
  }
}
