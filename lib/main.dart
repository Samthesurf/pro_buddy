import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'bloc/auth_cubit.dart';
import 'bloc/auth_state.dart';
import 'bloc/chat_cubit.dart';
import 'core/core.dart';
import 'core/routes.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AuthCubit>().state;
      _checkAuth(state);
    });
  }

  void _checkAuth(AuthState state) {
    if (state.status == AuthStatus.authenticated) {
      if (state.isOnboardingComplete) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
      }
    } else if (state.status == AuthStatus.unauthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
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
