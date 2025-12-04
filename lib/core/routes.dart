import 'package:flutter/material.dart';

import '../screens/progress_chat_screen.dart';

/// Route names for navigation
class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';

  // Onboarding routes
  static const String welcome = '/onboarding/welcome';
  static const String goalsInput = '/onboarding/goals';
  static const String appSelection = '/onboarding/apps';
  static const String onboardingSummary = '/onboarding/summary';

  // Main app routes
  static const String dashboard = '/dashboard';
  static const String progressChat = '/progress';
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
      case AppRoutes.splash:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Splash'),
          settings,
        );

      case AppRoutes.signIn:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Sign In'),
          settings,
        );

      case AppRoutes.signUp:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Sign Up'),
          settings,
        );

      case AppRoutes.welcome:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Welcome'),
          settings,
        );

      case AppRoutes.goalsInput:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Your Goals'),
          settings,
        );

      case AppRoutes.appSelection:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Select Apps'),
          settings,
        );

      case AppRoutes.onboardingSummary:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Summary'),
          settings,
        );

      case AppRoutes.dashboard:
        return _buildRoute(
          const _PlaceholderScreen(title: 'Dashboard'),
          settings,
        );

      case AppRoutes.progressChat:
        return _buildRoute(
          const ProgressChatScreen(),
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
        return _buildRoute(
          const _PlaceholderScreen(title: 'Notification Settings'),
          settings,
        );

      default:
        return _buildRoute(
          const _NotFoundScreen(),
          settings,
        );
    }
  }

  static MaterialPageRoute<T> _buildRoute<T>(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<T>(
      builder: (_) => page,
      settings: settings,
    );
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
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
            Text(
              '404',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed(
                AppRoutes.splash,
              ),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

