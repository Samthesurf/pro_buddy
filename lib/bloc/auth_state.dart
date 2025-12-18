import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isOnboardingComplete;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isOnboardingComplete = false,
  });

  factory AuthState.initial() => const AuthState();

  factory AuthState.authenticated(User user, {bool isOnboardingComplete = false}) => AuthState(
        status: AuthStatus.authenticated,
        user: user,
        isOnboardingComplete: isOnboardingComplete,
      );

  factory AuthState.unauthenticated() => const AuthState(
        status: AuthStatus.unauthenticated,
      );

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool? isOnboardingComplete,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
    );
  }

  @override
  List<Object?> get props => [status, user, isLoading, errorMessage, isOnboardingComplete];
}
