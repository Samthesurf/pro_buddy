import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';
import '../bloc/progress_streak_cubit.dart';
import '../bloc/onboarding_preferences_cubit.dart';
import '../bloc/daily_usage_summary_cubit.dart';
import '../bloc/usage_history_cubit.dart';
import '../core/routes.dart';
import '../core/cozy_theme.dart';
import 'cozy_dashboard_screen.dart';
import 'settings_screen.dart';
import 'usage_history_screen.dart';
import '../services/onboarding_storage.dart';

/// Cozy-themed main screen wrapper that provides the cozy theme context
class CozyMainScreen extends StatefulWidget {
  const CozyMainScreen({super.key});

  @override
  State<CozyMainScreen> createState() => _CozyMainScreenState();
}

class _CozyMainScreenState extends State<CozyMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Wrap with the Cozy theme
    return Theme(
      data: CozyTheme.light, // or use CozyTheme.dark based on system
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ProgressStreakCubit()..loadStreak()),
          BlocProvider(
            create: (_) => OnboardingPreferencesCubit()..loadPreferences(),
          ),
          BlocProvider(create: (_) => DailyUsageSummaryCubit()..loadSummary()),
          BlocProvider(
            create: (_) => UsageHistoryCubit()..loadHistory(limit: 20),
          ),
        ],
        child: _CozyMainScreenContent(
          currentIndex: _currentIndex,
          onIndexChanged: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

class _CozyMainScreenContent extends StatelessWidget {
  const _CozyMainScreenContent({
    required this.currentIndex,
    required this.onIndexChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const CozyDashboardScreen(),
      const UsageHistoryScreen(),
      const SettingsScreen(),
    ];

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (state.status == AuthStatus.unauthenticated) {
          // Check if we should go to onboarding (e.g. account deleted) or just sign in
          final hasSeenOnboarding = await OnboardingStorage.hasSeenOnboarding();
          if (!context.mounted) return;

          Navigator.of(context).pushNamedAndRemoveUntil(
            hasSeenOnboarding ? AppRoutes.signIn : AppRoutes.onboardingSplash,
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
            backgroundColor: CozyColors.surface,
            indicatorColor: CozyColors.primaryLight.withValues(alpha: 0.3),
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
