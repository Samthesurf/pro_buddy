/// Models for app usage monitoring and feedback

/// Represents an app usage event
class AppUsageEvent {
  final String packageName;
  final String appName;
  final DateTime timestamp;
  final Duration? duration;

  const AppUsageEvent({
    required this.packageName,
    required this.appName,
    required this.timestamp,
    this.duration,
  });

  factory AppUsageEvent.fromJson(Map<String, dynamic> json) {
    return AppUsageEvent(
      packageName: json['package_name'] as String,
      appName: json['app_name'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: json['duration_ms'] != null
          ? Duration(milliseconds: json['duration_ms'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'timestamp': timestamp.toIso8601String(),
      'duration_ms': duration?.inMilliseconds,
    };
  }

  @override
  String toString() => 'AppUsageEvent($appName at $timestamp)';
}

/// Alignment status of app usage with user goals
enum AlignmentStatus {
  aligned,
  neutral,
  misaligned,
}

extension AlignmentStatusExtension on AlignmentStatus {
  String get displayName {
    switch (this) {
      case AlignmentStatus.aligned:
        return 'Aligned';
      case AlignmentStatus.neutral:
        return 'Neutral';
      case AlignmentStatus.misaligned:
        return 'Misaligned';
    }
  }

  static AlignmentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'aligned':
        return AlignmentStatus.aligned;
      case 'misaligned':
        return AlignmentStatus.misaligned;
      default:
        return AlignmentStatus.neutral;
    }
  }
}

/// Feedback from AI about app usage
class UsageFeedback {
  final String id;
  final String userId;
  final String packageName;
  final String appName;
  final AlignmentStatus alignment;
  final String message;
  final String? reason;
  final DateTime createdAt;
  final bool notificationSent;

  const UsageFeedback({
    required this.id,
    required this.userId,
    required this.packageName,
    required this.appName,
    required this.alignment,
    required this.message,
    this.reason,
    required this.createdAt,
    this.notificationSent = false,
  });

  factory UsageFeedback.fromJson(Map<String, dynamic> json) {
    return UsageFeedback(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      packageName: json['package_name'] as String,
      appName: json['app_name'] as String,
      alignment: AlignmentStatusExtension.fromString(json['alignment'] as String),
      message: json['message'] as String,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      notificationSent: json['notification_sent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'package_name': packageName,
      'app_name': appName,
      'alignment': alignment.name,
      'message': message,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'notification_sent': notificationSent,
    };
  }

  UsageFeedback copyWith({
    String? id,
    String? userId,
    String? packageName,
    String? appName,
    AlignmentStatus? alignment,
    String? message,
    String? reason,
    DateTime? createdAt,
    bool? notificationSent,
  }) {
    return UsageFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      alignment: alignment ?? this.alignment,
      message: message ?? this.message,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      notificationSent: notificationSent ?? this.notificationSent,
    );
  }

  @override
  String toString() =>
      'UsageFeedback($appName: ${alignment.displayName} - $message)';
}

/// Daily usage summary
class DailyUsageSummary {
  final String userId;
  final DateTime date;
  final int alignedCount;
  final int neutralCount;
  final int misalignedCount;
  final Duration totalAlignedTime;
  final Duration totalMisalignedTime;
  final double alignmentScore;
  final List<UsageFeedback> feedbackItems;

  const DailyUsageSummary({
    required this.userId,
    required this.date,
    required this.alignedCount,
    required this.neutralCount,
    required this.misalignedCount,
    required this.totalAlignedTime,
    required this.totalMisalignedTime,
    required this.alignmentScore,
    required this.feedbackItems,
  });

  int get totalCount => alignedCount + neutralCount + misalignedCount;

  factory DailyUsageSummary.fromJson(Map<String, dynamic> json) {
    return DailyUsageSummary(
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      alignedCount: json['aligned_count'] as int,
      neutralCount: json['neutral_count'] as int,
      misalignedCount: json['misaligned_count'] as int,
      totalAlignedTime:
          Duration(milliseconds: json['total_aligned_time_ms'] as int),
      totalMisalignedTime:
          Duration(milliseconds: json['total_misaligned_time_ms'] as int),
      alignmentScore: (json['alignment_score'] as num).toDouble(),
      feedbackItems: (json['feedback_items'] as List<dynamic>)
          .map((f) => UsageFeedback.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'date': date.toIso8601String(),
      'aligned_count': alignedCount,
      'neutral_count': neutralCount,
      'misaligned_count': misalignedCount,
      'total_aligned_time_ms': totalAlignedTime.inMilliseconds,
      'total_misaligned_time_ms': totalMisalignedTime.inMilliseconds,
      'alignment_score': alignmentScore,
      'feedback_items': feedbackItems.map((f) => f.toJson()).toList(),
    };
  }
}

