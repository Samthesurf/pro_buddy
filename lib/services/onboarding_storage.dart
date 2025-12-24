import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Local onboarding persistence (per-install).
///
/// This is intentionally separate from the backend's `onboarding_complete`
/// field (which is per-account). We use this to ensure onboarding is shown
/// only to truly new installs/users.
class OnboardingStorage {
  OnboardingStorage._();

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.onboardingSeenKey) ?? false;
  }

  static Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingSeenKey, value);
  }
}
