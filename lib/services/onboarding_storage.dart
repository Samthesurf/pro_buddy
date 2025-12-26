import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Local onboarding persistence (per-install).
///
/// This is intentionally separate from the backend's `onboarding_complete`
/// field (which is per-account). We use this to ensure onboarding is shown
/// only to truly new installs/users.
///
/// IMPORTANT: On logout, we clear this flag so that if a NEW user signs up
/// on the same device, they get the proper onboarding experience. The backend's
/// `onboarding_complete` is the source of truth for EXISTING users.
class OnboardingStorage {
  OnboardingStorage._();

  static const String _lastOnboardedUserKey = 'last_onboarded_user_id';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.onboardingSeenKey) ?? false;
  }

  static Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingSeenKey, value);
  }

  /// Store the user ID that completed onboarding on this device.
  /// Used to detect when a different user signs in.
  static Future<void> setLastOnboardedUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) {
      await prefs.setString(_lastOnboardedUserKey, userId);
    } else {
      await prefs.remove(_lastOnboardedUserKey);
    }
  }

  /// Get the last user ID that completed onboarding on this device.
  static Future<String?> getLastOnboardedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOnboardedUserKey);
  }

  /// Clear all local onboarding state.
  /// Call this on logout so that new users on the same device
  /// get a proper onboarding experience.
  static Future<void> clearOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.onboardingSeenKey);
    await prefs.remove(_lastOnboardedUserKey);
  }
}
