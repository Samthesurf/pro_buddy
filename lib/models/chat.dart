/// Chat models for progress conversations with AI.

enum MessageRole { user, assistant }

enum EncouragementType { celebrate, support, curious, motivate }

/// A single chat message
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final EncouragementType? encouragementType;
  final List<String>? detectedTopics;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.encouragementType,
    this.detectedTopics,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      encouragementType: _parseEncouragementType(json['encouragement_type']),
      detectedTopics: json['detected_topics'] != null
          ? List<String>.from(json['detected_topics'])
          : null,
    );
  }

  static EncouragementType? _parseEncouragementType(String? type) {
    if (type == null) return null;
    switch (type) {
      case 'celebrate':
        return EncouragementType.celebrate;
      case 'support':
        return EncouragementType.support;
      case 'curious':
        return EncouragementType.curious;
      case 'motivate':
        return EncouragementType.motivate;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role == MessageRole.user ? 'user' : 'assistant',
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create a user message
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// Create an assistant message
  factory ChatMessage.assistant(
    String content, {
    EncouragementType? encouragementType,
    List<String>? detectedTopics,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
      encouragementType: encouragementType,
      detectedTopics: detectedTopics,
    );
  }
}

/// Progress report response from the API
class ProgressReportResponse {
  final String message;
  final EncouragementType encouragementType;
  final String? followUpQuestion;
  final bool progressStored;
  final List<String> detectedTopics;

  const ProgressReportResponse({
    required this.message,
    required this.encouragementType,
    this.followUpQuestion,
    this.progressStored = true,
    this.detectedTopics = const [],
  });

  factory ProgressReportResponse.fromJson(Map<String, dynamic> json) {
    return ProgressReportResponse(
      message: json['message'] ?? '',
      encouragementType:
          ChatMessage._parseEncouragementType(json['encouragement_type']) ??
              EncouragementType.support,
      followUpQuestion: json['follow_up_question'],
      progressStored: json['progress_stored'] ?? true,
      detectedTopics: json['detected_topics'] != null
          ? List<String>.from(json['detected_topics'])
          : [],
    );
  }
}

/// Progress summary from the API
class ProgressSummary {
  final String period;
  final int totalEntries;
  final List<String> keyAchievements;
  final List<String> recurringChallenges;
  final String aiInsight;

  const ProgressSummary({
    required this.period,
    required this.totalEntries,
    required this.keyAchievements,
    required this.recurringChallenges,
    required this.aiInsight,
  });

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      period: json['period'] ?? 'week',
      totalEntries: json['total_entries'] ?? 0,
      keyAchievements: json['key_achievements'] != null
          ? List<String>.from(json['key_achievements'])
          : [],
      recurringChallenges: json['recurring_challenges'] != null
          ? List<String>.from(json['recurring_challenges'])
          : [],
      aiInsight: json['ai_insight'] ?? '',
    );
  }
}
