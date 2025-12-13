/// Goal data model

class Goal {
  final String id;
  final String userId;
  final String content;
  final String? reason;
  final String? timeline;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Goal({
    required this.id,
    required this.userId,
    required this.content,
    this.reason,
    this.timeline,
    required this.createdAt,
    this.updatedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      reason: json['reason'] as String?,
      timeline: json['timeline'] as String?,
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
      'content': content,
      'reason': reason,
      'timeline': timeline,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Goal copyWith({
    String? id,
    String? userId,
    String? content,
    String? reason,
    String? timeline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      reason: reason ?? this.reason,
      timeline: timeline ?? this.timeline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Goal(id: $id, content: $content, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Goal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// User's complete goals profile
class GoalsProfile {
  final String userId;
  final List<Goal> goals;
  final String? summary;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GoalsProfile({
    required this.userId,
    required this.goals,
    this.summary,
    required this.createdAt,
    this.updatedAt,
  });

  factory GoalsProfile.fromJson(Map<String, dynamic> json) {
    return GoalsProfile(
      userId: json['user_id'] as String,
      goals: (json['goals'] as List<dynamic>)
          .map((g) => Goal.fromJson(g as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'goals': goals.map((g) => g.toJson()).toList(),
      'summary': summary,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  GoalsProfile copyWith({
    String? userId,
    List<Goal>? goals,
    String? summary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalsProfile(
      userId: userId ?? this.userId,
      goals: goals ?? this.goals,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}









