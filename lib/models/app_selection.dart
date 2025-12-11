/// App selection and classification models

/// Represents an installed app on the device
class InstalledApp {
  final String packageName;
  final String appName;
  final String? category;
  final bool isSystemApp;

  const InstalledApp({
    required this.packageName,
    required this.appName,
    this.category,
    this.isSystemApp = false,
  });

  factory InstalledApp.fromJson(Map<String, dynamic> json) {
    return InstalledApp(
      packageName: json['package_name'] as String,
      appName: json['app_name'] as String,
      category: json['category'] as String?,
      isSystemApp: json['is_system_app'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'category': category,
      'is_system_app': isSystemApp,
    };
  }

  @override
  String toString() => 'InstalledApp($appName, $packageName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InstalledApp && other.packageName == packageName;
  }

  @override
  int get hashCode => packageName.hashCode;
}

/// User's selection of an app with their reasoning
class AppSelection {
  final String id;
  final String userId;
  final String packageName;
  final String appName;
  final String reason;
  final int importanceRating;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AppSelection({
    required this.id,
    required this.userId,
    required this.packageName,
    required this.appName,
    required this.reason,
    required this.importanceRating,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppSelection.fromJson(Map<String, dynamic> json) {
    return AppSelection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      packageName: json['package_name'] as String,
      appName: json['app_name'] as String,
      reason: json['reason'] as String,
      importanceRating: json['importance_rating'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'package_name': packageName,
      'app_name': appName,
      'reason': reason,
      'importance_rating': importanceRating,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AppSelection copyWith({
    String? id,
    String? userId,
    String? packageName,
    String? appName,
    String? reason,
    int? importanceRating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSelection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      reason: reason ?? this.reason,
      importanceRating: importanceRating ?? this.importanceRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AppSelection($appName: $reason, importance: $importanceRating)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSelection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Classification of an app by AI
enum AppCategory {
  productivity,
  social,
  entertainment,
  gaming,
  utility,
  health,
  education,
  communication,
  finance,
  news,
  shopping,
  travel,
  other,
}

extension AppCategoryExtension on AppCategory {
  String get displayName {
    switch (this) {
      case AppCategory.productivity:
        return 'Productivity';
      case AppCategory.social:
        return 'Social Media';
      case AppCategory.entertainment:
        return 'Entertainment';
      case AppCategory.gaming:
        return 'Gaming';
      case AppCategory.utility:
        return 'Utility';
      case AppCategory.health:
        return 'Health & Fitness';
      case AppCategory.education:
        return 'Education';
      case AppCategory.communication:
        return 'Communication';
      case AppCategory.finance:
        return 'Finance';
      case AppCategory.news:
        return 'News';
      case AppCategory.shopping:
        return 'Shopping';
      case AppCategory.travel:
        return 'Travel';
      case AppCategory.other:
        return 'Other';
    }
  }

  static AppCategory fromString(String value) {
    return AppCategory.values.firstWhere(
      (c) => c.name == value.toLowerCase(),
      orElse: () => AppCategory.other,
    );
  }
}

/// AI-generated classification of an app
class AppClassification {
  final String packageName;
  final String appName;
  final AppCategory category;
  final String description;
  final List<String> typicalUses;
  final DateTime classifiedAt;

  const AppClassification({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.description,
    required this.typicalUses,
    required this.classifiedAt,
  });

  factory AppClassification.fromJson(Map<String, dynamic> json) {
    return AppClassification(
      packageName: json['package_name'] as String,
      appName: json['app_name'] as String,
      category: AppCategoryExtension.fromString(json['category'] as String),
      description: json['description'] as String,
      typicalUses: (json['typical_uses'] as List<dynamic>)
          .map((u) => u as String)
          .toList(),
      classifiedAt: DateTime.parse(json['classified_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'category': category.name,
      'description': description,
      'typical_uses': typicalUses,
      'classified_at': classifiedAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'AppClassification($appName: ${category.displayName})';
}








