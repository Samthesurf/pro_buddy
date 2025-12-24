import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'bloc/auth_cubit.dart';
import 'bloc/auth_state.dart';
import 'bloc/chat_cubit.dart';
import 'bloc/progress_score_cubit.dart';
import 'core/core.dart';
import 'services/onboarding_storage.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthCubit(),
        ),
        BlocProvider(
          create: (_) => ChatCubit(),
        ),
        BlocProvider(
          create: (_) => ProgressScoreCubit()..loadLatest(),
        ),
      ],
      child: const ProBuddyApp(),
    ),
  );
}

class ProBuddyApp extends StatelessWidget {
  const ProBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Navigation
      onGenerateRoute: AppRouter.generateRoute,
      home: const AuthWrapper(),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AuthCubit>().state;
      _checkAuth(state);
    });
  }

  Future<void> _checkAuth(AuthState state) async {
    if (_didNavigate || !mounted) return;

    if (state.status == AuthStatus.authenticated) {
      // Logged-in users always go straight to the dashboard.
      _didNavigate = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } else if (state.status == AuthStatus.unauthenticated) {
      // Onboarding is only for truly new installs. Returning (logged-out) users
      // go straight to auth.
      final hasSeenOnboarding = await OnboardingStorage.hasSeenOnboarding();
      if (!mounted) return;

      _didNavigate = true;
      Navigator.of(context).pushReplacementNamed(
        hasSeenOnboarding ? AppRoutes.signIn : AppRoutes.onboardingSplash,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        _checkAuth(state);
      },
      child: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
