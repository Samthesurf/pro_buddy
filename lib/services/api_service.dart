import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../core/constants.dart';

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
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[API] $obj'),
    ));
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

  // ==================== Onboarding Endpoints ====================

  /// Save user goals
  Future<Map<String, dynamic>> saveGoals({
    required String content,
    String? reason,
    String? timeline,
  }) async {
    final response = await _dio.post('/onboarding/goals', data: {
      'content': content,
      'reason': reason,
      'timeline': timeline,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Save app selections
  Future<Map<String, dynamic>> saveAppSelections({
    required List<Map<String, dynamic>> apps,
  }) async {
    final response = await _dio.post('/onboarding/apps', data: {
      'apps': apps,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Complete onboarding process
  Future<Map<String, dynamic>> completeOnboarding() async {
    final response = await _dio.post('/onboarding/complete');
    return response.data as Map<String, dynamic>;
  }

  /// Start the goal discovery / notification profile conversation
  Future<Map<String, dynamic>> startGoalDiscovery({bool reset = false}) async {
    final response = await _dio.post('/onboarding/goal-discovery/start', data: {
      'reset': reset,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Continue the goal discovery conversation
  Future<Map<String, dynamic>> sendGoalDiscoveryMessage({
    required String sessionId,
    required String message,
  }) async {
    final response = await _dio.post('/onboarding/goal-discovery/message', data: {
      'session_id': sessionId,
      'message': message,
    });
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
    final response = await _dio.post('/monitor/app-usage', data: {
      'package_name': packageName,
      'app_name': appName,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get usage history
  Future<Map<String, dynamic>> getUsageHistory({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final response = await _dio.get('/monitor/history', queryParameters: {
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
      if (limit != null) 'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get daily summary
  Future<Map<String, dynamic>> getDailySummary({DateTime? date}) async {
    final response = await _dio.get('/monitor/summary', queryParameters: {
      if (date != null) 'date': date.toIso8601String(),
    });
    return response.data as Map<String, dynamic>;
  }

  // ==================== Chat Endpoints ====================

  /// Report daily progress and get AI response
  Future<Map<String, dynamic>> reportProgress({
    required String message,
    bool isVoice = false,
  }) async {
    final response = await _dio.post('/chat/progress', data: {
      'message': message,
      'is_voice': isVoice,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Send a chat message and get AI response
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    bool includeHistory = true,
    int historyLimit = 10,
  }) async {
    final response = await _dio.post('/chat/message', data: {
      'message': message,
      'include_history': includeHistory,
      'history_limit': historyLimit,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get conversation history
  Future<Map<String, dynamic>> getChatHistory({int limit = 20}) async {
    final response = await _dio.get('/chat/history', queryParameters: {
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Get progress summary
  Future<Map<String, dynamic>> getProgressSummary({
    String period = 'week',
  }) async {
    final response = await _dio.get('/chat/summary', queryParameters: {
      'period': period,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Search progress entries
  Future<Map<String, dynamic>> searchProgress({
    required String query,
    int limit = 10,
  }) async {
    final response = await _dio.get('/chat/progress/search', queryParameters: {
      'query': query,
      'limit': limit,
    });
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
    } catch (e) {
      print('[AuthInterceptor] Failed to get token: $e');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 errors - token expired or invalid
    if (err.response?.statusCode == 401) {
      // Could trigger re-authentication here
      print('[AuthInterceptor] Unauthorized - token may be expired');
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
