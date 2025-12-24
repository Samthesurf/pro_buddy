import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/onboarding_storage.dart';
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
        // Once a user signs in on this install, we should never show onboarding again
        // (onboarding is only for brand new installs/users).
        await OnboardingStorage.setHasSeenOnboarding(true);

        // Fetch user profile to check onboarding status
        try {
          final profile = await ApiService.instance.getUserProfile();
          final isOnboardingComplete = profile['onboarding_complete'] as bool? ?? false;
          emit(AuthState.authenticated(user, isOnboardingComplete: isOnboardingComplete));
        } catch (e) {
          // If fetch fails (e.g. backend down or user not created yet),
          // default to false (show onboarding) to be safe for new users.
          // For existing users with network issues, this might force onboarding check again
          // which is acceptable or we could add a "checkLater" logic.
          // For now, assume false.
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
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapErrorToMessage(e),
      ));
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
          email: email, password: password, name: name);
      // State updated via stream listener
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapErrorToMessage(e),
      ));
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
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapErrorToMessage(e),
      ));
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _authService.signOut();
    } catch (_) {
      // Ignore errors on sign out
    }
    // State updated via stream listener
  }

  Future<void> resetAccount() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _authService.resetAccount();
      // After reset, we need to update state to trigger onboarding again.
      // Since we don't sign out, the stream listener won't fire a "new user" event necessarily,
      // but we updated the backend state to onboarding_complete=false.
      // We should manually emit the state change or re-fetch profile.
      
      if (state.user != null) {
        emit(AuthState.authenticated(state.user!, isOnboardingComplete: false));
      }
    } catch (e) {
       emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to reset account: $e',
      ));
    }
  }

  String _mapErrorToMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided for that user.';
        case 'email-already-in-use':
          return 'The account already exists for that email.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'weak-password':
          return 'The password provided is too weak.';
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
