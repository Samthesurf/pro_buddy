/// Models for the goal discovery / notification profile flow.

class NotificationProfile {
  final String? identity;
  final String? primaryGoal;
  final String? why;
  final List<String> motivators;
  final String? stakes;
  final int? importance1To5;
  final String? style;
  final String? preferredNameForUser;
  final String? preferredNameForAssistant;
  final List<String> helpfulApps;
  final List<String> riskyApps;
  final String? appIntentNotes;

  const NotificationProfile({
    this.identity,
    this.primaryGoal,
    this.why,
    this.motivators = const [],
    this.stakes,
    this.importance1To5,
    this.style,
    this.preferredNameForUser,
    this.preferredNameForAssistant,
    this.helpfulApps = const [],
    this.riskyApps = const [],
    this.appIntentNotes,
  });

  factory NotificationProfile.fromJson(Map<String, dynamic> json) {
    return NotificationProfile(
      identity: json['identity'],
      primaryGoal: json['primary_goal'],
      why: json['why'],
      motivators: (json['motivators'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      stakes: json['stakes'],
      importance1To5: json['importance_1_to_5'],
      style: json['style'],
      preferredNameForUser: json['preferred_name_for_user'],
      preferredNameForAssistant: json['preferred_name_for_assistant'],
      helpfulApps: (json['helpful_apps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      riskyApps: (json['risky_apps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      appIntentNotes: json['app_intent_notes'],
    );
  }
}

class GoalDiscoveryResponse {
  final String sessionId;
  final String message;
  final bool done;
  final NotificationProfile? profile;

  const GoalDiscoveryResponse({
    required this.sessionId,
    required this.message,
    required this.done,
    this.profile,
  });

  factory GoalDiscoveryResponse.fromJson(Map<String, dynamic> json) {
    return GoalDiscoveryResponse(
      sessionId: json['session_id'] ?? '',
      message: json['message'] ?? '',
      done: json['done'] ?? false,
      profile: json['profile'] != null
          ? NotificationProfile.fromJson(
              json['profile'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}



