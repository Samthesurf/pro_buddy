import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';

import 'bloc/auth_cubit.dart';
import 'bloc/auth_state.dart';
import 'bloc/chat_cubit.dart';
import 'bloc/goal_journey_cubit.dart';
import 'bloc/progress_score_cubit.dart';
import 'bloc/theme_cubit.dart';
import 'core/core.dart';
import 'services/onboarding_storage.dart';
import 'services/restoration_service.dart';
import 'services/restoration_route_observer.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/daily_progress_updater.dart';

/// Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase with generated options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service with tap handler
  await NotificationService.instance.initialize(onTap: _handleNotificationTap);

  // Initialize background service
  await BackgroundService.instance.initialize();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => ChatCubit()),
        BlocProvider(create: (_) => ProgressScoreCubit()..loadLatest()),
        BlocProvider(create: (_) => GoalJourneyCubit()..loadJourney()),
      ],
      child: const DailyProgressListener(
        child: ProBuddyApp(),
      ),
    ),
  );
}

/// Handle notification taps - navigate to progress chat with context
void _handleNotificationTap(NotificationPayload? payload) {
  if (payload == null) return;

  // Use the global navigator key to navigate
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  // All notification types lead to the progress chat screen
  // Pass the notification context as arguments
  navigator.pushNamed(
    AppRoutes.progressChat,
    arguments: {
      'notificationType': payload.type.name,
      'triggerApp': payload.appName,
      'triggerPackage': payload.packageName,
      'message': payload.message,
    },
  );
}

class ProBuddyApp extends StatefulWidget {
  const ProBuddyApp({super.key});

  @override
  State<ProBuddyApp> createState() => _ProBuddyAppState();
}

class _ProBuddyAppState extends State<ProBuddyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app goes to background, we don't mark it as proper shutdown
    // Only if the app is detached (killed) do we potentially want to restore
    if (state == AppLifecycleState.detached) {
      // App is being killed - this is rare to catch, but if we do,
      // mark it as proper shutdown if we can
      RestorationService.markProperShutdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Global navigator key for notification navigation
          navigatorKey: navigatorKey,

          // Enable state restoration
          restorationScopeId: 'pro_buddy_root',

          // Theme configuration - Cozy theme is now the official light mode!
          theme: CozyTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,

          // Navigation
          onGenerateRoute: AppRouter.generateRoute,
          home: const AuthWrapper(),

          // Track route changes for restoration
          navigatorObservers: [
            RestorationRouteObserver(),
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _didNavigate = false;
  AuthStatus? _previousStatus;
  bool _isRestoringState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRestoration();
    });
  }

  /// Check if we should restore from a previous session
  Future<void> _checkForRestoration() async {
    if (!mounted) return;

    final shouldRestore = await RestorationService.shouldRestore();

    if (shouldRestore) {
      // Try to restore to the last route
      final lastRoute = await RestorationService.getLastRoute();
      final lastRouteArgs = await RestorationService.getLastRouteArguments();

      if (lastRoute != null && mounted) {
        print('Restoring to last route: $lastRoute');
        _isRestoringState = true;
        _didNavigate = true;

        // Navigate to the last route
        Navigator.of(
          context,
        ).pushReplacementNamed(lastRoute, arguments: lastRouteArgs);
        return;
      }
    }

    // No restoration needed, proceed with normal auth check
    final state = context.read<AuthCubit>().state;
    _checkAuth(state);
  }

  Future<void> _checkAuth(AuthState state) async {
    if (!mounted || _isRestoringState) return;

    // If status changed from authenticated to unauthenticated, user signed out
    // Reset navigation flag and navigate to sign-in
    if (_previousStatus == AuthStatus.authenticated &&
        state.status == AuthStatus.unauthenticated) {
      _didNavigate = false; // Reset so we can navigate again
      // Clear restoration data on logout
      await RestorationService.markProperShutdown();
    }

    _previousStatus = state.status;

    if (_didNavigate) return;

    if (state.status == AuthStatus.authenticated) {
      // Check if user has completed onboarding
      if (state.isOnboardingComplete) {
        // User has completed onboarding - go to dashboard
        _didNavigate = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        // Save this route for restoration
        await RestorationService.saveRoute(AppRoutes.dashboard);
      } else {
        // User is authenticated but hasn't completed onboarding
        // Send them to app selection (they can skip if they want)
        _didNavigate = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.appSelection);
        await RestorationService.saveRoute(AppRoutes.appSelection);
      }
    } else if (state.status == AuthStatus.unauthenticated) {
      // Onboarding is only for truly new installs. Returning (logged-out) users
      // go straight to auth.
      final hasSeenOnboarding = await OnboardingStorage.hasSeenOnboarding();
      if (!mounted) return;

      _didNavigate = true;
      final route = hasSeenOnboarding
          ? AppRoutes.signIn
          : AppRoutes.onboardingSplash;
      Navigator.of(context).pushReplacementNamed(route);
      // Don't save auth routes for restoration - always start fresh on these
      await RestorationService.markProperShutdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        _checkAuth(state);
      },
      child: const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
