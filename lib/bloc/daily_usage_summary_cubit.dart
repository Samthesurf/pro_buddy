import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/usage_feedback.dart';
import '../services/api_service.dart';

class DailyUsageSummaryState {
  final DailyUsageSummary? summary;
  final bool isLoading;
  final String? errorMessage;

  const DailyUsageSummaryState({
    required this.summary,
    required this.isLoading,
    this.errorMessage,
  });

  factory DailyUsageSummaryState.initial() => const DailyUsageSummaryState(
        summary: null,
        isLoading: false,
        errorMessage: null,
      );

  DailyUsageSummaryState copyWith({
    DailyUsageSummary? summary,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DailyUsageSummaryState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage,
    );
  }
}

class DailyUsageSummaryCubit extends Cubit<DailyUsageSummaryState> {
  DailyUsageSummaryCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(DailyUsageSummaryState.initial());

  final ApiService _apiService;

  Future<void> loadSummary({DateTime? date}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    
    try {
      final response = await _apiService.getDailySummary(date: date);
      final summary = DailyUsageSummary.fromJson(response);
      
      emit(state.copyWith(summary: summary, isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load usage summary.',
        ),
      );
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }
}
