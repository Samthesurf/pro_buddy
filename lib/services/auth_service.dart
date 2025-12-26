import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'onboarding_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthService._();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Sign in with Email and Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Sync with backend
      await _syncWithBackend();

      return credential;
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      rethrow;
    }
  }

  /// Sign up with Email and Password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
      }

      // Sync with backend
      await _syncWithBackend();

      return credential;
    } catch (e) {
      debugPrint('Error signing up with email: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final userCredential = await _auth.signInWithCredential(credential);

      // Sync with backend
      await _syncWithBackend();

      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Clear local onboarding state BEFORE signing out.
      // This ensures that if a NEW user signs in on this device,
      // they will get the proper onboarding experience.
      // The backend's onboarding_complete flag is the source of truth
      // for existing users - we'll check that when they sign back in.
      await OnboardingStorage.clearOnboardingState();

      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Reset account (delete data)
  Future<void> resetAccount() async {
    try {
      await ApiService.instance.resetUserAccount();
      // Optional: Sign out after reset if desired, or let them continue as fresh user
      // User requested "keep using an account as a fresh account", so we don't sign out.
    } catch (e) {
      debugPrint('Error resetting account: $e');
      rethrow;
    }
  }

  /// Sync user with backend
  Future<void> _syncWithBackend() async {
    try {
      final result = await ApiService.instance.verifyToken();
      debugPrint('Synced with backend: $result');
    } catch (e) {
      // If backend sync fails, we might still want to let the user in locally?
      // Or maybe show an error. For now, we'll log it.
      // In a real app, you might retry or show a specific error.
      debugPrint('Failed to sync with backend: $e');
      // If strictly required, rethrow
      // rethrow;
    }
  }
}
