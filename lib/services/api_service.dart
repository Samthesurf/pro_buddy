import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../core/constants.dart';
import '../core/logger.dart';

/// API service for communicating with the Python backend
class ApiService {
  static ApiService? _instance;
  late final Dio _dio;

  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.apiTimeout,
        receiveTimeout: AppConstants.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add auth interceptor
    _dio.interceptors.add(AuthInterceptor());

    // Add logging interceptor for debug
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => appLogger.d('[API] $obj'),
      ),
    );
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  Dio get dio => _dio;

  // ==================== Auth Endpoints ====================

  /// Verify Firebase token and get/create user
  Future<Map<String, dynamic>> verifyToken() async {
    final response = await _dio.post('/auth/verify');
    return response.data as Map<String, dynamic>;
  }

  /// Get current user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await _dio.get('/user/profile');
    return response.data as Map<String, dynamic>;
  }

  /// Reset user account (delete data)
  Future<Map<String, dynamic>> resetUserAccount() async {
    final response = await _dio.delete('/auth/user/reset');
    return response.data as Map<String, dynamic>;
  }

  // ==================== Onboarding Endpoints ====================

  /// Save user goals
  Future<Map<String, dynamic>> saveGoals({
    required String content,
    String? reason,
    String? timeline,
  }) async {
    final response = await _dio.post(
      '/onboarding/goals',
      data: {'content': content, 'reason': reason, 'timeline': timeline},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Save app selections
  Future<Map<String, dynamic>> saveAppSelections({
    required List<Map<String, dynamic>> apps,
  }) async {
    final response = await _dio.post('/onboarding/apps', data: {'apps': apps});
    return response.data as Map<String, dynamic>;
  }

  /// Get app selections
  Future<Map<String, dynamic>> getAppSelections() async {
    final response = await _dio.get('/onboarding/apps');
    return response.data as Map<String, dynamic>;
  }

  /// Complete onboarding process
  Future<Map<String, dynamic>> completeOnboarding() async {
    final response = await _dio.post('/onboarding/complete');
    return response.data as Map<String, dynamic>;
  }

  /// Save onboarding preferences (challenges, habits, etc.) - NOT primary goals
  Future<Map<String, dynamic>> saveOnboardingPreferences({
    required List<String> challenges,
    required List<String> habits,
    double distractionHours = 0,
    double focusDurationMinutes = 0,
    int goalClarity = 5,
    String productiveTime = 'Morning',
    String checkInFrequency = 'Daily',
  }) async {
    final response = await _dio.post(
      '/onboarding/preferences',
      data: {
        'challenges': challenges,
        'habits': habits,
        'distraction_hours': distractionHours,
        'focus_duration_minutes': focusDurationMinutes,
        'goal_clarity': goalClarity,
        'productive_time': productiveTime,
        'check_in_frequency': checkInFrequency,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get onboarding preferences
  Future<Map<String, dynamic>> getOnboardingPreferences() async {
    final response = await _dio.get('/onboarding/preferences');
    return response.data as Map<String, dynamic>;
  }

  /// Get all user goals
  Future<Map<String, dynamic>> getGoals() async {
    final response = await _dio.get('/onboarding/goals');
    return response.data as Map<String, dynamic>;
  }

  /// Update a goal
  Future<Map<String, dynamic>> updateGoal({
    required String goalId,
    String? content,
    String? reason,
    String? timeline,
  }) async {
    final response = await _dio.put(
      '/onboarding/goals/$goalId',
      data: {
        if (content != null) 'content': content,
        if (reason != null) 'reason': reason,
        if (timeline != null) 'timeline': timeline,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Delete a goal
  Future<void> deleteGoal(String goalId) async {
    await _dio.delete('/onboarding/goals/$goalId');
  }

  /// Start the goal discovery / notification profile conversation
  Future<Map<String, dynamic>> startGoalDiscovery({bool reset = false}) async {
    final response = await _dio.post(
      '/onboarding/goal-discovery/start',
      data: {'reset': reset},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Continue the goal discovery conversation
  Future<Map<String, dynamic>> sendGoalDiscoveryMessage({
    required String sessionId,
    required String message,
  }) async {
    final response = await _dio.post(
      '/onboarding/goal-discovery/message',
      data: {'session_id': sessionId, 'message': message},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get the stored notification profile (if any)
  Future<Map<String, dynamic>> getNotificationProfile() async {
    final response = await _dio.get('/onboarding/notification-profile');
    return response.data as Map<String, dynamic>;
  }

  // ==================== Monitoring Endpoints ====================

  /// Report app usage and get feedback
  Future<Map<String, dynamic>> reportAppUsage({
    required String packageName,
    required String appName,
  }) async {
    final response = await _dio.post(
      '/monitor/app-usage',
      data: {'package_name': packageName, 'app_name': appName},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get usage history
  Future<Map<String, dynamic>> getUsageHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final response = await _dio.get(
      '/monitor/history',
      queryParameters: {
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
        if (limit != null) 'limit': limit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get daily summary
  Future<Map<String, dynamic>> getDailySummary({DateTime? date}) async {
    final response = await _dio.get(
      '/monitor/summary',
      queryParameters: {if (date != null) 'date': date.toIso8601String()},
    );
    return response.data as Map<String, dynamic>;
  }

  // ==================== Chat Endpoints ====================

  /// Report daily progress and get AI response
  Future<Map<String, dynamic>> reportProgress({
    required String message,
    bool isVoice = false,
    String? audioBase64, // Base64-encoded audio data
    String? audioMimeType, // e.g., "audio/wav", "audio/mp4"
  }) async {
    final response = await _dio.post(
      '/chat/progress',
      data: {
        'message': message,
        'is_voice': isVoice,
        if (audioBase64 != null) 'audio_data': audioBase64,
        if (audioMimeType != null) 'audio_mime_type': audioMimeType,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Send a chat message and get AI response
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    bool includeHistory = true,
    int historyLimit = 10,
  }) async {
    final response = await _dio.post(
      '/chat/message',
      data: {
        'message': message,
        'include_history': includeHistory,
        'history_limit': historyLimit,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get conversation history
  Future<Map<String, dynamic>> getChatHistory({int limit = 20}) async {
    final response = await _dio.get(
      '/chat/history',
      queryParameters: {'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get progress summary
  Future<Map<String, dynamic>> getProgressSummary({
    String period = 'week',
  }) async {
    final response = await _dio.get(
      '/chat/summary',
      queryParameters: {'period': period},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Search progress entries
  Future<Map<String, dynamic>> searchProgress({
    required String query,
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/chat/progress/search',
      queryParameters: {'query': query, 'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Finalize today's progress chat (compute % score + store memory)
  Future<Map<String, dynamic>> finalizeTodayProgress({
    required List<Map<String, dynamic>> messages,
  }) async {
    final response = await _dio.post(
      '/chat/finalize-today',
      data: {'messages': messages},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get latest conversation-based progress score (for dashboard)
  Future<Map<String, dynamic>> getLatestProgressScore() async {
    final response = await _dio.get('/chat/progress-score/latest');
    return response.data as Map<String, dynamic>;
  }

  /// Get progress score history (for streak calculation)
  Future<Map<String, dynamic>> getProgressScoreHistory({int limit = 30}) async {
    final response = await _dio.get(
      '/chat/progress-score/history',
      queryParameters: {'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  // ==================== Apps Endpoints ====================

  /// Get use cases for multiple apps (from cache or AI-generated)
  Future<Map<String, List<String>>> getAppUseCases(
    List<Map<String, String>> apps,
  ) async {
    if (apps.isEmpty) return {};

    try {
      // Use extended timeout for this endpoint since Gemini AI generation can take a while
      final response = await _dio.post(
        '/apps/use-cases/bulk',
        data: {
          'apps': apps
              .map(
                (app) => {
                  'package_name': app['package_name'],
                  'app_name': app['app_name'],
                },
              )
              .toList(),
        },
        options: Options(
          receiveTimeout: const Duration(
            minutes: 5,
          ), // 5 minutes for large AI requests
        ),
      );

      final results = response.data['results'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> useCases = {};

      for (final entry in results.entries) {
        final data = entry.value as Map<String, dynamic>? ?? {};
        final cases = data['use_cases'] as List<dynamic>? ?? [];
        useCases[entry.key] = cases.map((e) => e.toString()).toList();
      }

      return useCases;
    } catch (e, st) {
      appLogger.e(
        '[ApiService] Failed to get app use cases',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  /// Get universal fallback use cases
  static List<String> get universalUseCases => [
    'Work & Productivity',
    'Learning & Research',
    'Communication',
    'Health & Wellness',
    'Entertainment',
    'Organization',
    'Creativity',
    'Finance',
  ];

  // ==================== Goal Journey Endpoints ====================

  /// Generate a new journey from a goal
  Future<Map<String, dynamic>> generateJourney({
    required String goalContent,
    String? goalReason,
    String? goalId,
    String? identity,
    List<String>? challenges,
  }) async {
    final response = await _dio.post(
      '/journey/generate',
      data: {
        'goal_content': goalContent,
        if (goalReason != null) 'goal_reason': goalReason,
        if (goalId != null) 'goal_id': goalId,
        if (identity != null) 'identity': identity,
        if (challenges != null) 'challenges': challenges,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get the user's current active journey
  Future<Map<String, dynamic>?> getCurrentJourney() async {
    try {
      final response = await _dio.get('/journey');
      if (response.data == null) return null;
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      appLogger.i(
        '[ApiService] No current journey found',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Get a specific journey by ID
  Future<Map<String, dynamic>> getJourney(String journeyId) async {
    final response = await _dio.get('/journey/$journeyId');
    return response.data as Map<String, dynamic>;
  }

  /// Delete a journey
  Future<void> deleteJourney(String journeyId) async {
    await _dio.delete('/journey/$journeyId');
  }

  /// Update step status
  Future<Map<String, dynamic>> updateStepStatus({
    required String stepId,
    required String status,
    String? notes,
  }) async {
    final response = await _dio.put(
      '/journey/steps/$stepId/status',
      data: {'status': status, if (notes != null) 'notes': notes},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Update step custom title
  Future<Map<String, dynamic>> updateStepTitle({
    required String stepId,
    required String customTitle,
  }) async {
    final response = await _dio.put(
      '/journey/steps/$stepId/title',
      data: {'custom_title': customTitle},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Add a note to a step
  Future<Map<String, dynamic>> addStepNote({
    required String stepId,
    required String note,
  }) async {
    final response = await _dio.post(
      '/journey/steps/$stepId/notes',
      data: {'note': note},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Adjust journey based on current activity (AI-powered)
  Future<Map<String, dynamic>> adjustJourney({
    required String journeyId,
    required String currentActivity,
    String? additionalContext,
  }) async {
    final response = await _dio.post(
      '/journey/adjust',
      data: {
        'journey_id': journeyId,
        'current_activity': currentActivity,
        if (additionalContext != null) 'additional_context': additionalContext,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Choose a path at a decision point (updates the journey graph)
  Future<Map<String, dynamic>> chooseJourneyPath({
    required String decisionStepId,
    required String chosenStepId,
  }) async {
    final response = await _dio.post(
      '/journey/steps/$decisionStepId/choose-path',
      data: {'chosen_step_id': chosenStepId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Recalculate journey progress
  Future<Map<String, dynamic>> recalculateJourneyProgress(
    String journeyId,
  ) async {
    final response = await _dio.post('/journey/$journeyId/recalculate');
    return response.data as Map<String, dynamic>;
  }
}

/// Interceptor to add Firebase auth token to requests
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = firebase.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e, st) {
      appLogger.e(
        '[AuthInterceptor] Failed to get token',
        error: e,
        stackTrace: st,
      );
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 errors - token expired or invalid
    if (err.response?.statusCode == 401) {
      // Could trigger re-authentication here
      appLogger.w('[AuthInterceptor] Unauthorized - token may be expired');
    }
    handler.next(err);
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
