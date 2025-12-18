import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/chat.dart';
import '../models/goal_discovery.dart';
import '../services/api_service.dart';

class GoalDiscoveryState {
  final String? sessionId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool done;
  final NotificationProfile? profile;
  final String? errorMessage;

  const GoalDiscoveryState({
    required this.sessionId,
    required this.messages,
    required this.isLoading,
    required this.done,
    required this.profile,
    this.errorMessage,
  });

  factory GoalDiscoveryState.initial() => const GoalDiscoveryState(
        sessionId: null,
        messages: [],
        isLoading: false,
        done: false,
        profile: null,
        errorMessage: null,
      );

  GoalDiscoveryState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? done,
    NotificationProfile? profile,
    String? errorMessage,
  }) {
    return GoalDiscoveryState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      done: done ?? this.done,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

class GoalDiscoveryCubit extends Cubit<GoalDiscoveryState> {
  GoalDiscoveryCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(GoalDiscoveryState.initial());

  final ApiService _apiService;

  Future<void> start({bool reset = false}) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final raw = await _apiService.startGoalDiscovery(reset: reset);
      final res = GoalDiscoveryResponse.fromJson(raw);

      emit(
        state.copyWith(
          sessionId: res.sessionId,
          messages: [ChatMessage.assistant(res.message)],
          isLoading: false,
          done: res.done,
          profile: res.profile,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to start goal discovery.',
        ),
      );
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      await start();
      return;
    }

    final updatedMessages = [...state.messages, ChatMessage.user(trimmed)];
    emit(state.copyWith(messages: updatedMessages, isLoading: true));

    try {
      final raw = await _apiService.sendGoalDiscoveryMessage(
        sessionId: sessionId,
        message: trimmed,
      );
      final res = GoalDiscoveryResponse.fromJson(raw);

      emit(
        state.copyWith(
          messages: [...updatedMessages, ChatMessage.assistant(res.message)],
          isLoading: false,
          done: res.done,
          profile: res.profile ?? state.profile,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          messages: [
            ...updatedMessages,
            ChatMessage.assistant(
              "I'm having trouble connecting right now. Please try again in a moment.",
              encouragementType: EncouragementType.support,
            ),
          ],
          isLoading: false,
          errorMessage: 'Failed to send message.',
        ),
      );
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(errorMessage: null));
    }
  }
}
