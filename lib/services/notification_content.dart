import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal_discovery.dart';

/// Local (no-API) notification copy generator + cache.
///
/// This is intentionally deterministic + template-based so we can personalize
/// notifications without calling an LLM on-device or via API.
class NotificationContent {
  static String buildProgressCheckIn({
    required NotificationProfile profile,
    required String checkInFrequency,
    LastProgressScore? lastScore,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final variant = now.day % 3;

    final userName = (profile.preferredNameForUser ?? '').trim();
    final assistantName = (profile.preferredNameForAssistant ?? 'Pro Buddy').trim();
    final identity = (profile.identity ?? '').trim();
    final goal = (profile.primaryGoal ?? '').trim();
    final why = (profile.why ?? '').trim();
    final stakes = (profile.stakes ?? '').trim();
    final motivator = profile.motivators.isNotEmpty ? profile.motivators.first.trim() : '';
    final style = (profile.style ?? 'gentle').trim().toLowerCase();

    final namePrefix = userName.isNotEmpty ? 'Hey $userName,' : 'Hey,';
    final identityPhrase = identity.isNotEmpty ? ' as a $identity' : '';
    final goalPhrase = goal.isNotEmpty ? goal : 'your main goal';
    final freqHint = _frequencyHint(checkInFrequency);

    final scoreHint = lastScore != null
        ? 'Last score: ${lastScore.scorePercent}/100.'
        : '';

    final reasonHint = (lastScore?.reason ?? '').trim();
    final reasonShort = reasonHint.isNotEmpty
        ? (reasonHint.length > 90 ? '${reasonHint.substring(0, 90)}…' : reasonHint)
        : '';

    String promptLine;
    if (style == 'direct') {
      promptLine = 'Quick check-in: what did you do today for $goalPhrase?';
    } else if (style == 'playful') {
      promptLine = 'Quick check-in: what’s one “win” you got done for $goalPhrase today?';
    } else {
      promptLine = 'Quick check-in: how did $goalPhrase go today?';
    }

    String motivatorLine = '';
    if (stakes.isNotEmpty) {
      motivatorLine = 'Remember what’s at stake: $stakes';
    } else if (why.isNotEmpty) {
      motivatorLine = 'Remember why you’re doing this: $why';
    } else if (motivator.isNotEmpty) {
      motivatorLine = motivator;
    }

    // Variation for freshness without randomness.
    if (variant == 0) {
      return [
        namePrefix,
        '$assistantName here —$freqHint',
        promptLine,
        if (scoreHint.isNotEmpty) scoreHint,
      ].where((s) => s.trim().isNotEmpty).join(' ');
    }

    if (variant == 1) {
      return [
        namePrefix,
        'Small nudge$identityPhrase:',
        promptLine,
        if (motivatorLine.isNotEmpty) motivatorLine,
      ].where((s) => s.trim().isNotEmpty).join(' ');
    }

    return [
      namePrefix,
      'How’s it going with $goalPhrase today?',
      if (reasonShort.isNotEmpty) 'Last time you said: $reasonShort',
      if (motivatorLine.isNotEmpty) motivatorLine,
    ].where((s) => s.trim().isNotEmpty).join(' ');
  }

  static String _frequencyHint(String checkInFrequency) {
    switch (checkInFrequency.trim().toLowerCase()) {
      case 'multiple times daily':
        return ' (I’ll check in a couple times today)';
      case 'weekly':
        return ' (weekly check-in)';
      case 'daily':
      default:
        return ' (daily check-in)';
    }
  }
}

class LastProgressScore {
  final int scorePercent;
  final String reason;
  final String dateUtc;

  const LastProgressScore({
    required this.scorePercent,
    required this.reason,
    required this.dateUtc,
  });
}

class NotificationCache {
  static const _kProfileJson = 'notification_profile_json';
  static const _kCheckInFrequency = 'check_in_frequency';
  static const _kLastScorePercent = 'last_progress_score_percent';
  static const _kLastScoreReason = 'last_progress_score_reason';
  static const _kLastScoreDateUtc = 'last_progress_score_date_utc';

  static Future<void> saveNotificationProfile(NotificationProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileJson, jsonEncode(profile.toJson()));
  }

  static Future<NotificationProfile?> loadNotificationProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfileJson);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCheckInFrequency(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCheckInFrequency, value);
  }

  static Future<String> loadCheckInFrequency({String fallback = 'Daily'}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCheckInFrequency) ?? fallback;
  }

  static Future<void> saveLastProgressScore(LastProgressScore score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastScorePercent, score.scorePercent);
    await prefs.setString(_kLastScoreReason, score.reason);
    await prefs.setString(_kLastScoreDateUtc, score.dateUtc);
  }

  static Future<LastProgressScore?> loadLastProgressScore() async {
    final prefs = await SharedPreferences.getInstance();
    final percent = prefs.getInt(_kLastScorePercent);
    final reason = prefs.getString(_kLastScoreReason);
    final dateUtc = prefs.getString(_kLastScoreDateUtc);
    if (percent == null || reason == null || dateUtc == null) return null;
    return LastProgressScore(scorePercent: percent, reason: reason, dateUtc: dateUtc);
  }
}
