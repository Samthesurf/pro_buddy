import 'package:flutter/material.dart';

import '../screens/auth_screen.dart';
import '../screens/main_screen.dart';
import '../screens/cozy_main_screen.dart';
import '../screens/progress_chat_screen.dart';
import '../screens/app_selection_screen.dart';
import '../screens/goal_discovery_screen.dart';
import '../screens/goals_input_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/onboarding/quiz_screen.dart';
import '../screens/onboarding/challenges_screen.dart';
import '../screens/onboarding/routine_builder_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/goal_discovery_cubit.dart';
import '../screens/settings/notification_settings_screen.dart';

/// Route names for navigation
class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';

  // New onboarding flow
  static const String onboardingSplash = '/onboarding/splash';
  static const String onboardingQuiz = '/onboarding/quiz';
  static const String onboardingChallenges = '/onboarding/challenges';
  static const String onboardingRoutine = '/onboarding/routine';

  // Legacy onboarding routes (kept for compatibility)
  static const String welcome = '/onboarding/welcome';
  static const String goalsInput = '/onboarding/goals';
  static const String appSelection = '/onboarding/apps';
  static const String onboardingSummary = '/onboarding/summary';

  // Main app routes
  static const String dashboard = '/dashboard';
  static const String cozyDashboard = '/cozy-dashboard';
  static const String progressChat = '/progress';
  static const String goalDiscovery = '/goals/discovery';
  static const String usageHistory = '/history';
  static const String settings = '/settings';

  // Settings sub-routes
  static const String editGoals = '/settings/goals';
  static const String editApps = '/settings/apps';
  static const String notifications = '/settings/notifications';
}

/// Route generator for the app
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // New onboarding flow - make splash the entry point
      case AppRoutes.splash:
        return _buildRoute(const OnboardingSplashScreen(), settings);

      case AppRoutes.onboardingSplash:
        return _buildRoute(const OnboardingSplashScreen(), settings);

      case AppRoutes.onboardingQuiz:
        return _buildRoute(const OnboardingQuizScreen(), settings);

      case AppRoutes.onboardingChallenges:
        return _buildRoute(const OnboardingChallengesScreen(), settings);

      case AppRoutes.onboardingRoutine:
        return _buildRoute(const OnboardingRoutineBuilderScreen(), settings);

      case AppRoutes.signIn:
        return _buildRoute(const AuthScreen(isSignIn: true), settings);

      case AppRoutes.signUp:
        return _buildRoute(const AuthScreen(isSignIn: false), settings);

      // Legacy onboarding routes
      case AppRoutes.welcome:
        return _buildRoute(const WelcomeScreen(), settings);

      case AppRoutes.goalsInput:
        return _buildRoute(const GoalsInputScreen(), settings);

      case AppRoutes.appSelection:
        final args = settings.arguments as Map<String, dynamic>?;
        final fromSettings = args?['fromSettings'] as bool? ?? false;
        return _buildRoute(
          AppSelectionScreen(fromSettings: fromSettings),
          settings,
        );

      case AppRoutes.onboardingSummary:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Summary'),
          settings,
        );

      case AppRoutes.dashboard:
        return _buildRoute(const MainScreen(), settings);

      case AppRoutes.cozyDashboard:
        return _buildRoute(const CozyMainScreen(), settings);

      case AppRoutes.progressChat:
        return _buildRoute(const ProgressChatScreen(), settings);

      case AppRoutes.goalDiscovery:
        return _buildRoute(
          BlocProvider(
            create: (_) => GoalDiscoveryCubit()..start(),
            child: const GoalDiscoveryScreen(),
          ),
          settings,
        );

      case AppRoutes.usageHistory:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Usage History'),
          settings,
        );

      case AppRoutes.settings:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Settings'),
          settings,
        );

      case AppRoutes.editGoals:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Edit Goals'),
          settings,
        );

      case AppRoutes.editApps:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Edit Apps'),
          settings,
        );

      case AppRoutes.notifications:
        return _buildRoute(const NotificationSettingsScreen(), settings);

      default:
        return _buildRoute(const _NotFoundScreen(), settings);
    }
  }

  static MaterialPageRoute<T> _buildRoute<T>(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<T>(builder: (_) => page, settings: settings);
  }
}

/// Temporary placeholder screen - will be replaced with actual screens
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Coming soon...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 404 Not Found screen
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('404', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
