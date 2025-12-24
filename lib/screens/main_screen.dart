import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';
import '../bloc/progress_streak_cubit.dart';
import '../bloc/onboarding_preferences_cubit.dart';
import '../bloc/daily_usage_summary_cubit.dart';
import '../bloc/usage_history_cubit.dart';
import '../core/routes.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'usage_history_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Provide dashboard-specific cubits at this level
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProgressStreakCubit()..loadStreak(),
        ),
        BlocProvider(
          create: (_) => OnboardingPreferencesCubit()..loadPreferences(),
        ),
        BlocProvider(
          create: (_) => DailyUsageSummaryCubit()..loadSummary(),
        ),
        BlocProvider(
          create: (_) => UsageHistoryCubit()..loadHistory(limit: 20),
        ),
      ],
      child: _MainScreenContent(
        currentIndex: _currentIndex,
        onIndexChanged: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _MainScreenContent extends StatelessWidget {
  const _MainScreenContent({
    required this.currentIndex,
    required this.onIndexChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const DashboardScreen(),
      const UsageHistoryScreen(),
      const SettingsScreen(),
    ];

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.signIn,
            (route) => false,
          );
        }
      },
      child: Scaffold(
        body: screens[currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onIndexChanged,
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: Theme.of(context).colorScheme.primaryContainer,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
