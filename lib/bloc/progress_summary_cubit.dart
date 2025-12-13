import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/chat.dart';
import '../services/api_service.dart';

class ProgressSummaryState {
  final ProgressSummary? summary;
  final bool isLoading;
  final String selectedPeriod;
  final String? errorMessage;

  const ProgressSummaryState({
    required this.summary,
    required this.isLoading,
    required this.selectedPeriod,
    this.errorMessage,
  });

  factory ProgressSummaryState.initial() => const ProgressSummaryState(
        summary: null,
        isLoading: true,
        selectedPeriod: 'week',
        errorMessage: null,
      );

  ProgressSummaryState copyWith({
    ProgressSummary? summary,
    bool? isLoading,
    String? selectedPeriod,
    String? errorMessage,
  }) {
    return ProgressSummaryState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      errorMessage: errorMessage,
    );
  }
}

class ProgressSummaryCubit extends Cubit<ProgressSummaryState> {
  ProgressSummaryCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(ProgressSummaryState.initial());

  final ApiService _apiService;

  Future<void> loadSummary({String? period}) async {
    final targetPeriod = period ?? state.selectedPeriod;
    emit(
      state.copyWith(
        isLoading: true,
        selectedPeriod: targetPeriod,
        errorMessage: null,
      ),
    );

    try {
      final response = await _apiService.getProgressSummary(
        period: targetPeriod,
      );
      emit(
        state.copyWith(
          summary: ProgressSummary.fromJson(response),
          isLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          summary: null,
          isLoading: false,
          errorMessage: 'Failed to load progress summary.',
        ),
      );
    }
  }

  void changePeriod(String period) {
    if (period == state.selectedPeriod && state.summary != null) return;
    loadSummary(period: period);
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(errorMessage: null));
    }
  }
}


