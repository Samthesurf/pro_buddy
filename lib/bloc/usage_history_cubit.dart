import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/usage_feedback.dart';
import '../services/api_service.dart';

class UsageHistoryState {
  final List<UsageFeedback> items;
  final bool isLoading;
  final String? errorMessage;

  const UsageHistoryState({
    required this.items,
    required this.isLoading,
    this.errorMessage,
  });

  factory UsageHistoryState.initial() => const UsageHistoryState(
        items: [],
        isLoading: false,
        errorMessage: null,
      );

  UsageHistoryState copyWith({
    List<UsageFeedback>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UsageHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage,
    );
  }
}

class UsageHistoryCubit extends Cubit<UsageHistoryState> {
  UsageHistoryCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(UsageHistoryState.initial());

  final ApiService _apiService;

  Future<void> loadHistory({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    
    try {
      final response = await _apiService.getUsageHistory(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      
      final items = (response['items'] as List<dynamic>?)
              ?.map((item) => UsageFeedback.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
      
      emit(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load usage history.',
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
