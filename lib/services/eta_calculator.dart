/// ETA (Estimated Time of Achievement) Calculator
///
/// Calculates the estimated time to complete a goal journey entirely on
/// the client side, without requiring any API calls. The calculation is
/// based on the user's actual performance vs AI-estimated durations.

import '../models/goal_journey.dart';

class ETACalculator {
  /// Main calculation method - returns ETAData for a journey
  static ETAData calculate(GoalJourney journey) {
    final now = DateTime.now();
    final journeyStart = journey.journeyStartedAt;
    final daysElapsed = now.difference(journeyStart).inDays;

    // Get completed and remaining steps on main path
    final completedSteps = journey.mainPath
        .where((s) => s.status == StepStatus.completed)
        .toList();

    final remainingSteps = journey.mainPath
        .where(
          (s) =>
              s.status != StepStatus.completed &&
              s.status != StepStatus.skipped,
        )
        .toList();

    // ─────────────────────────────────────────────────
    // STEP 1: Calculate average days per step (actual)
    // ─────────────────────────────────────────────────
    double avgDaysPerStep;

    if (completedSteps.isEmpty) {
      // No data yet - use AI estimates
      avgDaysPerStep = _getAverageEstimatedDays(remainingSteps);
    } else {
      // Calculate based on actual performance
      final totalActualDays = completedSteps.fold<int>(
        0,
        (sum, step) => sum + (step.actualDaysSpent ?? step.estimatedDays),
      );
      avgDaysPerStep = totalActualDays / completedSteps.length;
    }

    // ─────────────────────────────────────────────────
    // STEP 2: Calculate velocity score
    // ─────────────────────────────────────────────────
    // Velocity > 1.0 = ahead of schedule
    // Velocity = 1.0 = on track
    // Velocity < 1.0 = behind schedule
    double velocityScore = 1.0;

    if (completedSteps.isNotEmpty) {
      final expectedDaysForCompleted = completedSteps.fold<int>(
        0,
        (sum, step) => sum + step.estimatedDays,
      );
      final actualDaysForCompleted = completedSteps.fold<int>(
        0,
        (sum, step) => sum + (step.actualDaysSpent ?? step.estimatedDays),
      );

      if (actualDaysForCompleted > 0) {
        velocityScore = expectedDaysForCompleted / actualDaysForCompleted;
      }
    }

    // ─────────────────────────────────────────────────
    // STEP 3: Estimate remaining days
    // ─────────────────────────────────────────────────
    int estimatedRemainingDays;

    if (completedSteps.isEmpty) {
      // Use AI estimates directly
      estimatedRemainingDays = remainingSteps.fold<int>(
        0,
        (sum, step) => sum + step.estimatedDays,
      );
    } else {
      // Use actual average, adjusted by velocity
      estimatedRemainingDays =
          (remainingSteps.length * avgDaysPerStep / velocityScore).round();
    }

    // Handle edge case: journey complete
    if (remainingSteps.isEmpty) {
      estimatedRemainingDays = 0;
    }

    // ─────────────────────────────────────────────────
    // STEP 4: Calculate estimated completion date
    // ─────────────────────────────────────────────────
    final estimatedCompletion = now.add(Duration(days: estimatedRemainingDays));

    // ─────────────────────────────────────────────────
    // STEP 5: Generate human-readable display text
    // ─────────────────────────────────────────────────
    final displayText = _formatETADisplay(
      estimatedRemainingDays,
      velocityScore,
    );

    // Calculate total estimated days for all steps
    final totalEstimatedDays = journey.mainPath.fold<int>(
      0,
      (sum, s) => sum + s.estimatedDays,
    );

    return ETAData(
      estimatedCompletionDate: estimatedCompletion,
      totalEstimatedDays: totalEstimatedDays,
      daysElapsed: daysElapsed,
      stepsCompleted: completedSteps.length,
      averageDaysPerStep: avgDaysPerStep,
      velocityScore: velocityScore,
      displayText: displayText,
    );
  }

  /// Get average estimated days from a list of steps
  static double _getAverageEstimatedDays(List<GoalStep> steps) {
    if (steps.isEmpty) return 14.0; // Default 2 weeks
    return steps.fold<int>(0, (sum, s) => sum + s.estimatedDays) / steps.length;
  }

  /// Format the ETA display text with velocity indicator
  static String _formatETADisplay(int daysRemaining, double velocity) {
    String timeText;

    if (daysRemaining <= 0) {
      timeText = "Almost there!";
    } else if (daysRemaining <= 7) {
      timeText = "~$daysRemaining day${daysRemaining > 1 ? 's' : ''} to go";
    } else if (daysRemaining <= 30) {
      final weeks = (daysRemaining / 7).round();
      timeText = "~$weeks week${weeks > 1 ? 's' : ''} to go";
    } else if (daysRemaining <= 365) {
      final months = (daysRemaining / 30).round();
      timeText = "~$months month${months > 1 ? 's' : ''} to go";
    } else {
      final years = (daysRemaining / 365).round();
      timeText = "~$years year${years > 1 ? 's' : ''} to go";
    }

    // Add velocity indicator emoji
    if (velocity >= 1.3) {
      return "🚀 $timeText (ahead of schedule!)";
    } else if (velocity >= 0.9) {
      return "✨ $timeText (on track)";
    } else if (velocity >= 0.7) {
      return "📊 $timeText (a bit behind)";
    } else {
      return "💪 $timeText (let's pick up the pace!)";
    }
  }

  /// Get progress percentage as a string
  static String getProgressPercentage(GoalJourney journey) {
    final percent = (journey.overallProgress * 100).toInt();
    return "$percent%";
  }

  /// Get a motivational message based on progress
  static String getMotivationalMessage(GoalJourney journey, ETAData eta) {
    final progress = journey.overallProgress;
    final velocity = eta.velocityScore;

    if (journey.isComplete) {
      return "🎉 Congratulations! You've achieved your goal!";
    }

    if (progress == 0) {
      return "🌟 Every journey begins with a single step. Let's go!";
    }

    if (progress < 0.25) {
      if (velocity >= 1.0) {
        return "🔥 Great start! You're building momentum!";
      }
      return "🌱 You've started your journey. Keep going!";
    }

    if (progress < 0.50) {
      if (velocity >= 1.2) {
        return "⚡ You're crushing it! Almost halfway there!";
      }
      return "💪 Making solid progress. Keep pushing forward!";
    }

    if (progress < 0.75) {
      if (velocity >= 1.0) {
        return "🌟 Over halfway! The destination is in sight!";
      }
      return "🏃 You're past the halfway point. Stay focused!";
    }

    // 75%+ completion
    if (velocity >= 1.0) {
      return "🔥 So close! You're on fire!";
    }
    return "🎯 Almost there! Final push!";
  }

  /// Calculate the celebration type based on progress milestones
  static CelebrationType? checkMilestoneCelebration(
    double previousProgress,
    double newProgress,
  ) {
    // Check if we crossed a milestone
    if (previousProgress < 0.25 && newProgress >= 0.25) {
      return CelebrationType.milestone25;
    }
    if (previousProgress < 0.50 && newProgress >= 0.50) {
      return CelebrationType.milestone50;
    }
    if (previousProgress < 0.75 && newProgress >= 0.75) {
      return CelebrationType.milestone75;
    }
    if (previousProgress < 1.0 && newProgress >= 1.0) {
      return CelebrationType.journeyCompleted;
    }
    return null;
  }
}

/// Types of celebrations triggered at different milestones
enum CelebrationType {
  stepCompleted, // Single step done
  milestone25, // 25% complete
  milestone50, // 50% complete
  milestone75, // 75% complete
  journeyCompleted, // Goal reached!
}

/// Extension for celebration configuration
extension CelebrationTypeExtension on CelebrationType {
  /// Number of confetti particles
  int get confettiCount {
    switch (this) {
      case CelebrationType.stepCompleted:
        return 50;
      case CelebrationType.milestone25:
        return 100;
      case CelebrationType.milestone50:
        return 150;
      case CelebrationType.milestone75:
        return 200;
      case CelebrationType.journeyCompleted:
        return 500;
    }
  }

  /// Duration of the celebration animation
  Duration get duration {
    switch (this) {
      case CelebrationType.stepCompleted:
        return const Duration(seconds: 2);
      case CelebrationType.milestone25:
      case CelebrationType.milestone50:
      case CelebrationType.milestone75:
        return const Duration(seconds: 3);
      case CelebrationType.journeyCompleted:
        return const Duration(seconds: 5);
    }
  }

  /// Banner text to display (null for step completed)
  String? get bannerText {
    switch (this) {
      case CelebrationType.stepCompleted:
        return null;
      case CelebrationType.milestone25:
        return "🎉 25% COMPLETE! 🎉";
      case CelebrationType.milestone50:
        return "🎉 HALFWAY THERE! 🎉";
      case CelebrationType.milestone75:
        return "🎉 75% COMPLETE! 🎉";
      case CelebrationType.journeyCompleted:
        return "🏆 GOAL ACHIEVED! 🏆";
    }
  }

  /// Whether this celebration should show a banner
  bool get showBanner => bannerText != null;

  /// Whether to play a sound effect
  bool get playSound {
    switch (this) {
      case CelebrationType.stepCompleted:
        return false;
      case CelebrationType.milestone25:
      case CelebrationType.milestone50:
      case CelebrationType.milestone75:
        return true;
      case CelebrationType.journeyCompleted:
        return true;
    }
  }
}
