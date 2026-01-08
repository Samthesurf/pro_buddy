import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/logger.dart';
import '../models/goal_journey.dart';
import '../services/api_service.dart';
import '../services/eta_calculator.dart';

/// State for the Goal Journey feature
class GoalJourneyState {
  final GoalJourney? journey;
  final ETAData? etaData;
  final bool isLoading;
  final bool isGenerating;
  final String? error;
  final GoalStep? selectedStep;
  final CelebrationType? pendingCelebration;

  // For optimistic updates
  final Map<String, StepStatus> pendingStatusChanges;

  const GoalJourneyState({
    this.journey,
    this.etaData,
    this.isLoading = false,
    this.isGenerating = false,
    this.error,
    this.selectedStep,
    this.pendingCelebration,
    this.pendingStatusChanges = const {},
  });

  factory GoalJourneyState.initial() => const GoalJourneyState();

  bool get hasJourney => journey != null;
  bool get isComplete => journey?.isComplete ?? false;
  double get progress => journey?.overallProgress ?? 0.0;

  GoalJourneyState copyWith({
    GoalJourney? journey,
    ETAData? etaData,
    bool? isLoading,
    bool? isGenerating,
    String? error,
    GoalStep? selectedStep,
    CelebrationType? pendingCelebration,
    Map<String, StepStatus>? pendingStatusChanges,
    bool clearError = false,
    bool clearCelebration = false,
    bool clearSelectedStep = false,
  }) {
    return GoalJourneyState(
      journey: journey ?? this.journey,
      etaData: etaData ?? this.etaData,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError ? null : (error ?? this.error),
      selectedStep: clearSelectedStep
          ? null
          : (selectedStep ?? this.selectedStep),
      pendingCelebration: clearCelebration
          ? null
          : (pendingCelebration ?? this.pendingCelebration),
      pendingStatusChanges: pendingStatusChanges ?? this.pendingStatusChanges,
    );
  }
}

/// Cubit for managing Goal Journey state
class GoalJourneyCubit extends Cubit<GoalJourneyState> {
  GoalJourneyCubit({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance,
      super(GoalJourneyState.initial());

  final ApiService _apiService;

  /// Load the user's current journey (if any)
  Future<void> loadJourney() async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final data = await _apiService.getCurrentJourney();

      if (data == null) {
        emit(state.copyWith(isLoading: false, journey: null));
        return;
      }

      final journey = GoalJourney.fromJson(data);
      final etaData = ETACalculator.calculate(journey);

      emit(
        state.copyWith(journey: journey, etaData: etaData, isLoading: false),
      );
    } catch (e, st) {
      appLogger.e(
        '[GoalJourneyCubit] Error loading journey',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(isLoading: false, error: 'Failed to load journey'));
    }
  }

  /// Generate a new journey from a goal
  Future<void> generateJourney({
    required String goalContent,
    String? goalReason,
    String? goalId,
    String? identity,
    List<String>? challenges,
  }) async {
    if (state.isGenerating) return;
    emit(state.copyWith(isGenerating: true, clearError: true));

    try {
      final data = await _apiService.generateJourney(
        goalContent: goalContent,
        goalReason: goalReason,
        goalId: goalId,
        identity: identity,
        challenges: challenges,
      );

      final journey = GoalJourney.fromJson(
        data['journey'] as Map<String, dynamic>,
      );
      final etaData = ETACalculator.calculate(journey);

      emit(
        state.copyWith(journey: journey, etaData: etaData, isGenerating: false),
      );
    } catch (e, st) {
      appLogger.e(
        '[GoalJourneyCubit] Error generating journey',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          isGenerating: false,
          error: 'Failed to generate journey. Please try again.',
        ),
      );
    }
  }

  /// Update a step's status
  Future<void> updateStepStatus({
    required String stepId,
    required StepStatus status,
    String? notes,
  }) async {
    final journey = state.journey;
    if (journey == null) return;

    // Store previous progress for milestone detection
    final previousProgress = journey.overallProgress;

    // Optimistic update
    final updatedSteps = journey.steps.map((step) {
      if (step.id == stepId) {
        return step.copyWith(
          status: status,
          startedAt: status == StepStatus.inProgress
              ? DateTime.now()
              : step.startedAt,
          completedAt: status == StepStatus.completed
              ? DateTime.now()
              : step.completedAt,
          notes: notes != null ? [...step.notes, notes] : step.notes,
        );
      }
      return step;
    }).toList();

    // If completing a step, unlock the next one
    if (status == StepStatus.completed) {
      final completedStepIndex = updatedSteps.indexWhere((s) => s.id == stepId);
      if (completedStepIndex >= 0 &&
          completedStepIndex + 1 < updatedSteps.length) {
        final nextStep = updatedSteps[completedStepIndex + 1];
        if (nextStep.status == StepStatus.locked && nextStep.isOnMainPath) {
          updatedSteps[completedStepIndex + 1] = nextStep.copyWith(
            status: StepStatus.available,
          );
        }
      }
    }

    // Calculate new progress
    final mainSteps = updatedSteps.where((s) => s.isOnMainPath).toList();
    final completedCount = mainSteps
        .where((s) => s.status == StepStatus.completed)
        .length;
    final newProgress = mainSteps.isNotEmpty
        ? completedCount / mainSteps.length
        : 0.0;

    final updatedJourney = journey.copyWith(
      steps: updatedSteps,
      overallProgress: newProgress,
      updatedAt: DateTime.now(),
    );

    final newEtaData = ETACalculator.calculate(updatedJourney);

    // Check for milestone celebrations
    CelebrationType? celebration;
    if (status == StepStatus.completed) {
      celebration = ETACalculator.checkMilestoneCelebration(
        previousProgress,
        newProgress,
      );
      celebration ??= CelebrationType.stepCompleted;
    }

    emit(
      state.copyWith(
        journey: updatedJourney,
        etaData: newEtaData,
        pendingCelebration: celebration,
        pendingStatusChanges: {...state.pendingStatusChanges, stepId: status},
      ),
    );

    // Sync with server
    try {
      await _apiService.updateStepStatus(
        stepId: stepId,
        status: status.name.toLowerCase(),
        notes: notes,
      );

      // Remove from pending changes
      final newPending = Map<String, StepStatus>.from(
        state.pendingStatusChanges,
      );
      newPending.remove(stepId);
      emit(state.copyWith(pendingStatusChanges: newPending));
    } catch (e, st) {
      appLogger.e(
        '[GoalJourneyCubit] Error updating step status',
        error: e,
        stackTrace: st,
      );
      // Revert optimistic update on error
      emit(
        state.copyWith(
          journey: journey,
          error: 'Failed to update step. Please try again.',
        ),
      );
    }
  }

  /// Add a note to a step
  Future<void> addStepNote({
    required String stepId,
    required String note,
  }) async {
    final journey = state.journey;
    if (journey == null) return;

    try {
      await _apiService.addStepNote(stepId: stepId, note: note);

      // Update local state
      final updatedSteps = journey.steps.map((step) {
        if (step.id == stepId) {
          return step.copyWith(notes: [...step.notes, note]);
        }
        return step;
      }).toList();

      emit(
        state.copyWith(
          journey: journey.copyWith(
            steps: updatedSteps,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    } catch (e, st) {
      appLogger.e(
        '[GoalJourneyCubit] Error adding note',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(error: 'Failed to add note'));
    }
  }

  /// Update a step's custom title
  Future<void> updateStepTitle({
    required String stepId,
    required String customTitle,
  }) async {
    final journey = state.journey;
    if (journey == null) return;

    try {
      await _apiService.updateStepTitle(
        stepId: stepId,
        customTitle: customTitle,
      );

      final updatedSteps = journey.steps.map((step) {
        if (step.id == stepId) {
          return step.copyWith(customTitle: customTitle);
        }
        return step;
      }).toList();

      emit(
        state.copyWith(
          journey: journey.copyWith(
            steps: updatedSteps,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    } catch (e, st) {
      appLogger.e(
        '[GoalJourneyCubit] Error updating title',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(error: 'Failed to update title'));
    }
  }

  /// Adjust journey based on user's current activity (AI-powered)
  Future<void> adjustJourney({
    required String currentActivity,
    String? additionalContext,
  }) async {
    final journey = state.journey;
    if (journey == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final data = await _apiService.adjustJourney(
        journeyId: journey.id,
        currentActivity: currentActivity,
        additionalContext: additionalContext,
      );

      final updatedJourney = GoalJourney.fromJson(
        data['journey'] as Map<String, dynamic>,
      );
      final newEtaData = ETACalculator.calculate(updatedJourney);

      emit(
        state.copyWith(
          journey: updatedJourney,
          etaData: newEtaData,
          isLoading: false,
        ),
      );
    } catch (e, st) {
      appLogger.e(
        '[GoalJourneyCubit] Error adjusting journey',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Failed to adjust journey. Please try again.',
        ),
      );
    }
  }

  /// Delete the current journey
  Future<void> deleteJourney() async {
    final journey = state.journey;
    if (journey == null) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      await _apiService.deleteJourney(journey.id);
      emit(GoalJourneyState.initial());
    } catch (e, st) {
      appLogger.e(
        '[GoalJourneyCubit] Error deleting journey',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(isLoading: false, error: 'Failed to delete journey'));
    }
  }

  /// Select a step for viewing details
  void selectStep(GoalStep step) {
    emit(state.copyWith(selectedStep: step));
  }

  /// Clear step selection
  void clearSelectedStep() {
    emit(state.copyWith(clearSelectedStep: true));
  }

  /// Clear pending celebration after it's been shown
  void clearCelebration() {
    emit(state.copyWith(clearCelebration: true));
  }

  /// Clear error
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  /// Recalculate ETA based on current journey state
  void recalculateETA() {
    final journey = state.journey;
    if (journey == null) return;

    final etaData = ETACalculator.calculate(journey);
    emit(state.copyWith(etaData: etaData));
  }

  /// Start the current step (mark as in progress)
  Future<void> startCurrentStep() async {
    final currentStep = state.journey?.currentStep;
    if (currentStep == null) return;
    if (currentStep.status != StepStatus.available) return;

    await updateStepStatus(
      stepId: currentStep.id,
      status: StepStatus.inProgress,
    );
  }

  /// Complete the current step
  Future<void> completeCurrentStep({String? notes}) async {
    final currentStep = state.journey?.currentStep;
    if (currentStep == null) return;
    if (currentStep.status != StepStatus.inProgress) return;

    await updateStepStatus(
      stepId: currentStep.id,
      status: StepStatus.completed,
      notes: notes,
    );
  }

  /// Get motivational message based on progress
  String getMotivationalMessage() {
    final journey = state.journey;
    final eta = state.etaData;
    if (journey == null || eta == null) {
      return '🌟 Start your journey today!';
    }
    return ETACalculator.getMotivationalMessage(journey, eta);
  }
}
