import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_service.dart';

class OnboardingPreferencesState {
  final List<String> challenges;
  final List<String> habits;
  final double distractionHours;
  final double focusDurationMinutes;
  final int goalClarity;
  final String productiveTime;
  final String checkInFrequency;
  final bool isLoading;
  final String? errorMessage;

  const OnboardingPreferencesState({
    required this.challenges,
    required this.habits,
    required this.distractionHours,
    required this.focusDurationMinutes,
    required this.goalClarity,
    required this.productiveTime,
    required this.checkInFrequency,
    required this.isLoading,
    this.errorMessage,
  });

  factory OnboardingPreferencesState.initial() => const OnboardingPreferencesState(
        challenges: [],
        habits: [],
        distractionHours: 0,
        focusDurationMinutes: 0,
        goalClarity: 5,
        productiveTime: 'Morning',
        checkInFrequency: 'Daily',
        isLoading: false,
        errorMessage: null,
      );

  OnboardingPreferencesState copyWith({
    List<String>? challenges,
    List<String>? habits,
    double? distractionHours,
    double? focusDurationMinutes,
    int? goalClarity,
    String? productiveTime,
    String? checkInFrequency,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingPreferencesState(
      challenges: challenges ?? this.challenges,
      habits: habits ?? this.habits,
      distractionHours: distractionHours ?? this.distractionHours,
      focusDurationMinutes: focusDurationMinutes ?? this.focusDurationMinutes,
      goalClarity: goalClarity ?? this.goalClarity,
      productiveTime: productiveTime ?? this.productiveTime,
      checkInFrequency: checkInFrequency ?? this.checkInFrequency,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage,
    );
  }
}

class OnboardingPreferencesCubit extends Cubit<OnboardingPreferencesState> {
  OnboardingPreferencesCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(OnboardingPreferencesState.initial());

  final ApiService _apiService;

  Future<void> loadPreferences() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    
    try {
      final response = await _apiService.getOnboardingPreferences();
      
      emit(
        state.copyWith(
          challenges: (response['challenges'] as List<dynamic>?)?.cast<String>() ?? [],
          habits: (response['habits'] as List<dynamic>?)?.cast<String>() ?? [],
          distractionHours: (response['distraction_hours'] as num?)?.toDouble() ?? 0,
          focusDurationMinutes: (response['focus_duration_minutes'] as num?)?.toDouble() ?? 0,
          goalClarity: (response['goal_clarity'] as num?)?.toInt() ?? 5,
          productiveTime: response['productive_time'] as String? ?? 'Morning',
          checkInFrequency: response['check_in_frequency'] as String? ?? 'Daily',
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load preferences.',
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


