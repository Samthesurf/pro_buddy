/// Data collected during the onboarding flow.
class OnboardingData {
  OnboardingData({
    this.distractionHours = 0,
    this.focusDurationMinutes = 0,
    this.goalClarity = 5,
    this.productiveTime = 'Morning',
    this.checkInFrequency = 'Daily',
    this.selectedChallenges = const [],
    this.selectedHabits = const [],
  });

  /// Hours per day lost to distracting apps (0-8)
  final double distractionHours;

  /// How long user can focus before checking phone (in minutes, 5-120)
  final double focusDurationMinutes;

  /// Goal clarity rating (1-10)
  final int goalClarity;

  /// When user is most productive
  final String productiveTime;

  /// How often user wants check-ins
  final String checkInFrequency;

  /// Selected digital challenges/distractions
  final List<String> selectedChallenges;

  /// Selected productivity habits
  final List<String> selectedHabits;

  OnboardingData copyWith({
    double? distractionHours,
    double? focusDurationMinutes,
    int? goalClarity,
    String? productiveTime,
    String? checkInFrequency,
    List<String>? selectedChallenges,
    List<String>? selectedHabits,
  }) {
    return OnboardingData(
      distractionHours: distractionHours ?? this.distractionHours,
      focusDurationMinutes: focusDurationMinutes ?? this.focusDurationMinutes,
      goalClarity: goalClarity ?? this.goalClarity,
      productiveTime: productiveTime ?? this.productiveTime,
      checkInFrequency: checkInFrequency ?? this.checkInFrequency,
      selectedChallenges: selectedChallenges ?? this.selectedChallenges,
      selectedHabits: selectedHabits ?? this.selectedHabits,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distraction_hours': distractionHours,
      'focus_duration_minutes': focusDurationMinutes,
      'goal_clarity': goalClarity,
      'productive_time': productiveTime,
      'check_in_frequency': checkInFrequency,
      'challenges': selectedChallenges,
      'habits': selectedHabits,
    };
  }
}

/// A challenge/distraction option for selection.
class Challenge {
  const Challenge({
    required this.id,
    required this.label,
    required this.emoji,
    required this.category,
  });

  final String id;
  final String label;
  final String emoji;
  final String category;
}

/// A productivity habit option for selection.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.category,
  });

  final String id;
  final String name;
  final String imagePath;
  final String category;
}

/// Predefined challenges grouped by category.
class OnboardingChallenges {
  static const List<Challenge> all = [
    // Digital Distractions
    Challenge(id: 'doomscrolling', label: 'Doomscrolling', emoji: '📱', category: 'Digital Distractions'),
    Challenge(id: 'notifications', label: 'Notification Anxiety', emoji: '🔔', category: 'Digital Distractions'),
    Challenge(id: 'social_media', label: 'Social Media Rabbit Holes', emoji: '🕳️', category: 'Digital Distractions'),
    Challenge(id: 'streaming', label: 'YouTube/Streaming Binges', emoji: '📺', category: 'Digital Distractions'),

    // Focus Blockers
    Challenge(id: 'procrastination', label: 'Procrastination', emoji: '⏳', category: 'Focus Blockers'),
    Challenge(id: 'task_switching', label: 'Task Switching', emoji: '🔀', category: 'Focus Blockers'),
    Challenge(id: 'decision_fatigue', label: 'Decision Fatigue', emoji: '🤔', category: 'Focus Blockers'),
    Challenge(id: 'meeting_overload', label: 'Meeting Overload', emoji: '📅', category: 'Focus Blockers'),

    // Mental Barriers
    Challenge(id: 'low_motivation', label: 'Low Motivation', emoji: '🪫', category: 'Mental Barriers'),
    Challenge(id: 'brain_fog', label: 'Brain Fog', emoji: '🌫️', category: 'Mental Barriers'),
    Challenge(id: 'perfectionism', label: 'Perfectionism', emoji: '🎯', category: 'Mental Barriers'),
    Challenge(id: 'burnout', label: 'Burnout', emoji: '🔥', category: 'Mental Barriers'),
  ];

  static List<String> get categories => 
      all.map((c) => c.category).toSet().toList();

  static List<Challenge> byCategory(String category) =>
      all.where((c) => c.category == category).toList();
}

/// Predefined productivity habits.
class OnboardingHabits {
  static const List<Habit> all = [
    Habit(
      id: 'deep_work',
      name: 'Deep Work Block',
      imagePath: 'assets/images/habits/guy_on_laptop.png',
      category: 'Focus',
    ),
    Habit(
      id: 'morning_planning',
      name: 'Morning Planning',
      imagePath: 'assets/images/habits/open_book_1.png',
      category: 'Planning',
    ),
    Habit(
      id: 'weekly_review',
      name: 'Weekly Review',
      imagePath: 'assets/images/habits/weekly_checklist.png',
      category: 'Planning',
    ),
    Habit(
      id: 'phone_free',
      name: 'Phone-Free Focus',
      imagePath: 'assets/images/habits/locker_pen_phone.png',
      category: 'Boundaries',
    ),
    Habit(
      id: 'notification_detox',
      name: 'Notification Detox',
      imagePath: 'assets/images/habits/do_not_disturb.png',
      category: 'Boundaries',
    ),
    Habit(
      id: 'journaling',
      name: 'Journaling',
      imagePath: 'assets/images/habits/book_pen_blue_towel.png',
      category: 'Focus',
    ),
    Habit(
      id: 'evening_shutdown',
      name: 'Evening Shutdown',
      imagePath: 'assets/images/habits/closing_laptop.png',
      category: 'Boundaries',
    ),
    Habit(
      id: 'pomodoro',
      name: 'Pomodoro Sessions',
      imagePath: 'assets/images/habits/pomodoro.png',
      category: 'Focus',
    ),
  ];

  static const List<String> categories = ['All', 'Focus', 'Planning', 'Boundaries'];

  static List<Habit> byCategory(String category) {
    if (category == 'All') return all;
    return all.where((h) => h.category == category).toList();
  }
}
