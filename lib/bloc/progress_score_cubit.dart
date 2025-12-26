import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_service.dart';

class ProgressScoreState {
  final int? scorePercent;
  final String? reason;
  final String? dateUtc;
  final bool isLoading;
  final String? errorMessage;

  const ProgressScoreState({
    required this.scorePercent,
    required this.reason,
    required this.dateUtc,
    required this.isLoading,
    this.errorMessage,
  });

  factory ProgressScoreState.initial() => const ProgressScoreState(
    scorePercent: null,
    reason: null,
    dateUtc: null,
    isLoading: false,
    errorMessage: null,
  );

  ProgressScoreState copyWith({
    int? scorePercent,
    String? reason,
    String? dateUtc,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProgressScoreState(
      scorePercent: scorePercent ?? this.scorePercent,
      reason: reason ?? this.reason,
      dateUtc: dateUtc ?? this.dateUtc,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage,
    );
  }
}

class ProgressScoreCubit extends Cubit<ProgressScoreState> {
  ProgressScoreCubit({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance,
      super(ProgressScoreState.initial());

  final ApiService _apiService;

  Future<void> loadLatest() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final raw = await _apiService.getLatestProgressScore();
      final score = raw['score'] as Map<String, dynamic>?;
      if (score == null) {
        emit(state.copyWith(isLoading: false));
        return;
      }
      emit(
        state.copyWith(
          scorePercent: (score['score_percent'] as num?)?.round(),
          reason: score['reason'] as String?,
          dateUtc: score['date_utc'] as String?,
          isLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load progress score.',
        ),
      );
    }
  }

  void setLatest({
    required int scorePercent,
    required String reason,
    required String dateUtc,
  }) {
    emit(
      state.copyWith(
        scorePercent: scorePercent,
        reason: reason,
        dateUtc: dateUtc,
        isLoading: false,
      ),
    );
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  /// Reset all progress score state. Call this when the user signs out
  /// to prevent stale data from appearing for a different user.
  void reset() {
    emit(ProgressScoreState.initial());
  }
}
