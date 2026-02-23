import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart';

import 'bloc/auth_cubit.dart';
import 'bloc/auth_state.dart';
import 'bloc/chat_cubit.dart';
import 'bloc/goal_journey_cubit.dart';
import 'bloc/navigation_cubit.dart';
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

  // Initialize HydratedStorage
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory(
            (await getApplicationDocumentsDirectory()).path,
          ),
  );

  // Initialize notification service with tap handler
  await NotificationService.instance.initialize(onTap: _handleNotificationTap);

  // Ensure scheduled notifications are re-registered (important after device reboot)
  await NotificationService.instance.ensureDailyReminderScheduled();

  // Initialize background service (also registers periodic tasks)
  await BackgroundService.instance.initialize();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => AuthCubit()),
        BlocProvider(create: (_) => ChatCubit()),
        BlocProvider(create: (_) => NavigationCubit()),
        BlocProvider(create: (_) => ProgressScoreCubit()..loadLatest()),
        BlocProvider(create: (_) => GoalJourneyCubit()..loadJourney()),
      ],
      child: const DailyProgressListener(child: ProBuddyApp()),
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
            RestorationRouteObserver(context.read<NavigationCubit>()),
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

  @override
  void initState() {
    super.initState();
    // Check current state in case we missed the initial emission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AuthCubit>().state;
      if (state.status != AuthStatus.initial) {
        _checkAuth(state);
      }
    });
  }

  Future<void> _checkAuth(AuthState state) async {
    if (!mounted) return;

    // If status changed from authenticated to unauthenticated, user signed out
    // Reset navigation flag and navigate to sign-in
    if (_previousStatus == AuthStatus.authenticated &&
        state.status == AuthStatus.unauthenticated) {
      _didNavigate = false; // Reset so we can navigate again
      // Clear saved route on logout
      context.read<NavigationCubit>().clearRoute();
    }

    _previousStatus = state.status;

    if (_didNavigate) return;

    if (state.status == AuthStatus.authenticated) {
      _didNavigate = true;

      // Check for saved route first (Restoration via HydratedCubit)
      final navState = context.read<NavigationCubit>().state;
      if (navState.lastRoute != null) {
        appLogger.i('Restoring to last route: ${navState.lastRoute}');
        Navigator.of(context).pushReplacementNamed(
          navState.lastRoute!,
          arguments: navState.lastArgs,
        );
        return;
      }

      // Check if user has completed onboarding
      if (state.isOnboardingComplete) {
        // User has completed onboarding - go to dashboard
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        // Save this route as base
        context.read<NavigationCubit>().setLastRoute(AppRoutes.dashboard);
      } else {
        // User is authenticated but hasn't completed onboarding
        // Send them to app selection (they can skip if they want)
        Navigator.of(context).pushReplacementNamed(AppRoutes.appSelection);
        context.read<NavigationCubit>().setLastRoute(AppRoutes.appSelection);
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
