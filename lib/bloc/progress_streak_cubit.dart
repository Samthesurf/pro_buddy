import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_service.dart';

class ProgressStreakState {
  final int streak;
  final bool isLoading;
  final String? errorMessage;

  const ProgressStreakState({
    required this.streak,
    required this.isLoading,
    this.errorMessage,
  });

  factory ProgressStreakState.initial() => const ProgressStreakState(
        streak: 0,
        isLoading: false,
        errorMessage: null,
      );

  ProgressStreakState copyWith({
    int? streak,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProgressStreakState(
      streak: streak ?? this.streak,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage,
    );
  }
}

class ProgressStreakCubit extends Cubit<ProgressStreakState> {
  ProgressStreakCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(ProgressStreakState.initial());

  final ApiService _apiService;

  Future<void> loadStreak() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    
    try {
      final response = await _apiService.getProgressScoreHistory(limit: 100);
      final items = response['items'] as List<dynamic>? ?? [];
      
      // Calculate streak: consecutive days (UTC) with finalized progress
      final streak = _calculateStreak(items);
      
      emit(state.copyWith(streak: streak, isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load progress streak.',
        ),
      );
    }
  }

  int _calculateStreak(List<dynamic> items) {
    if (items.isEmpty) return 0;

    // Parse dates and sort them (should already be sorted DESC from API)
    final dates = items
        .map((item) {
          final dateStr = item['date_utc'] as String?;
          if (dateStr == null || dateStr.isEmpty) return null;
          try {
            return DateTime.parse(dateStr);
          } catch (_) {
            return null;
          }
        })
        .where((d) => d != null)
        .cast<DateTime>()
        .toList();

    if (dates.isEmpty) return 0;

    // Get today's date in UTC (date only, no time)
    final nowUtc = DateTime.now().toUtc();
    final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    
    // Check if the most recent entry is today or yesterday
    // (streak is valid if we logged today OR yesterday)
    final mostRecent = dates.first;
    final mostRecentDate = DateTime.utc(mostRecent.year, mostRecent.month, mostRecent.day);
    
    final daysDiff = todayUtc.difference(mostRecentDate).inDays;
    
    // If most recent is more than 1 day ago, streak is broken
    if (daysDiff > 1) return 0;
    
    // Count consecutive days
    int streak = 1;
    
    for (int i = 1; i < dates.length; i++) {
      final currentDate = DateTime.utc(dates[i].year, dates[i].month, dates[i].day);
      final previousDate = DateTime.utc(dates[i - 1].year, dates[i - 1].month, dates[i - 1].day);
      
      final diff = previousDate.difference(currentDate).inDays;
      
      if (diff == 1) {
        // Consecutive day
        streak++;
      } else if (diff == 0) {
        // Same day (duplicate entries), skip
        continue;
      } else {
        // Gap found, stop counting
        break;
      }
    }
    
    return streak;
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }
}
