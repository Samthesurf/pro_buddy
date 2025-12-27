import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/onboarding_storage.dart';
import '../services/restoration_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  late StreamSubscription<User?> _userSubscription;

  AuthCubit({AuthService? authService})
    : _authService = authService ?? AuthService.instance,
      super(AuthState.initial()) {
    _init();
  }

  void _init() {
    _userSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        // Check if this is a different user than who was previously onboarded on this device
        final lastOnboardedUserId =
            await OnboardingStorage.getLastOnboardedUserId();
        final isNewUserOnDevice =
            lastOnboardedUserId != null && lastOnboardedUserId != user.uid;

        if (isNewUserOnDevice) {
          // A different user just signed in - clear any cached onboarding state
          // so we rely purely on backend's onboarding_complete flag
          await OnboardingStorage.clearOnboardingState();
          print(
            'Different user detected. Previous: $lastOnboardedUserId, Current: ${user.uid}',
          );
        }

        // Fetch user profile to check onboarding status from the BACKEND (source of truth)
        try {
          final profile = await ApiService.instance.getUserProfile();
          final isOnboardingComplete =
              profile['onboarding_complete'] as bool? ?? false;

          // Only set local onboarding flags if backend confirms onboarding is complete
          // This prevents new users from accidentally skipping onboarding
          if (isOnboardingComplete) {
            await OnboardingStorage.setHasSeenOnboarding(true);
            await OnboardingStorage.setLastOnboardedUserId(user.uid);
          }

          emit(
            AuthState.authenticated(
              user,
              isOnboardingComplete: isOnboardingComplete,
            ),
          );
        } catch (e) {
          // If fetch fails (e.g. backend down or user not created yet),
          // default to false (show onboarding) to be safe for new users.
          print('Error fetching user profile: $e');
          emit(AuthState.authenticated(user, isOnboardingComplete: false));
        }
      } else {
        emit(AuthState.unauthenticated());
      }
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _authService.signInWithEmail(email: email, password: password);
      // State updated via stream listener
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, errorMessage: _mapErrorToMessage(e)),
      );
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      // State updated via stream listener
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, errorMessage: _mapErrorToMessage(e)),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        // User cancelled
        emit(state.copyWith(isLoading: false));
      }
      // State updated via stream listener
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, errorMessage: _mapErrorToMessage(e)),
      );
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _authService.signOut();
      // Clear restoration data so we don't try to restore after logout
      await RestorationService.clearRestorationData();
    } catch (_) {
      // Ignore errors on sign out
    }
    // State updated via stream listener
  }

  Future<void> refreshProfile() async {
    // Re-check profile from backend (useful after updates)
    if (state.user == null) return;

    try {
      final profile = await ApiService.instance.getUserProfile();
      final isOnboardingComplete =
          profile['onboarding_complete'] as bool? ?? false;

      if (isOnboardingComplete != state.isOnboardingComplete) {
        emit(state.copyWith(isOnboardingComplete: isOnboardingComplete));
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> completeOnboarding() async {
    if (state.user == null) return;

    // 1. Update local storage immediately for fast next-startup check
    await OnboardingStorage.setHasSeenOnboarding(true);
    await OnboardingStorage.setLastOnboardedUserId(state.user!.uid);

    // 2. Update memory state immediately so UI reacts without waiting for a re-fetch
    emit(state.copyWith(isOnboardingComplete: true));
  }

  Future<void> resetAccount() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _authService.resetAccount();
      // After reset, we need to update state to trigger onboarding again.
      // Since we don't sign out, the stream listener won't fire a "new user" event necessarily,
      // but we updated the backend state to onboarding_complete=false.
      // We should manually emit the state change or re-fetch profile.

      // Clear local onboarding state to match backend
      await OnboardingStorage.clearOnboardingState();

      if (state.user != null) {
        emit(AuthState.authenticated(state.user!, isOnboardingComplete: false));
      }
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to reset account: $e',
        ),
      );
    }
  }

  String _mapErrorToMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email. Please sign up to create a new account.';
        case 'wrong-password':
          return 'Wrong password provided for that user.';
        case 'email-already-in-use':
          return 'The account already exists for that email.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-credential':
          return 'Invalid login credentials. Please check your email and password.';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return error.toString();
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
