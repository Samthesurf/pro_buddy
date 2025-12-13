import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/chat.dart';
import '../services/api_service.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool showInitialPrompt;
  final bool hasLoadedHistory;
  final String? errorMessage;

  const ChatState({
    required this.messages,
    required this.isLoading,
    required this.showInitialPrompt,
    required this.hasLoadedHistory,
    this.errorMessage,
  });

  factory ChatState.initial() => const ChatState(
        messages: [],
        isLoading: false,
        showInitialPrompt: true,
        hasLoadedHistory: false,
        errorMessage: null,
      );

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? showInitialPrompt,
    bool? hasLoadedHistory,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      showInitialPrompt: showInitialPrompt ?? this.showInitialPrompt,
      hasLoadedHistory: hasLoadedHistory ?? this.hasLoadedHistory,
      errorMessage: errorMessage,
    );
  }
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({ApiService? apiService})
      : _apiService = apiService ?? ApiService.instance,
        super(ChatState.initial());

  final ApiService _apiService;

  Future<void> loadHistory({int limit = 20}) async {
    if (state.hasLoadedHistory) return;

    try {
      final response = await _apiService.getChatHistory(limit: limit);
      final messages = (response['messages'] as List<dynamic>? ?? [])
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      emit(
        state.copyWith(
          messages: messages,
          showInitialPrompt: messages.isEmpty,
          hasLoadedHistory: true,
          errorMessage: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          hasLoadedHistory: true,
          errorMessage: 'Failed to load conversation history.',
        ),
      );
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final updatedMessages = [...state.messages, ChatMessage.user(trimmed)];
    emit(
      state.copyWith(
        messages: updatedMessages,
        isLoading: true,
        showInitialPrompt: false,
        errorMessage: null,
      ),
    );

    try {
      final response = await _apiService.reportProgress(message: trimmed);
      final progressResponse = ProgressReportResponse.fromJson(response);

      final assistantMessage = ChatMessage.assistant(
        progressResponse.message,
        encouragementType: progressResponse.encouragementType,
        detectedTopics: progressResponse.detectedTopics,
      );

      emit(
        state.copyWith(
          messages: [...updatedMessages, assistantMessage],
          isLoading: false,
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


