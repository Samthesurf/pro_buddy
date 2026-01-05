import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/progress_streak_cubit.dart';
import '../bloc/onboarding_preferences_cubit.dart';
import '../bloc/daily_usage_summary_cubit.dart';
import '../bloc/usage_history_cubit.dart';
import '../core/cozy_theme.dart';
import '../widgets/navigation_shell.dart';
import 'cozy_dashboard_screen.dart';
import 'settings_screen.dart';
import 'goals_screen.dart';

/// Cozy-themed main screen wrapper that provides the warm cozy theme context.
/// For the default Material theme, use [MainScreen] instead.
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
        child: NavigationShell(
          currentIndex: _currentIndex,
          onIndexChanged: (index) => setState(() => _currentIndex = index),
          backgroundColor: CozyColors.surface,
          indicatorColor: CozyColors.primaryLight.withValues(alpha: 0.3),
          screens: const [
            CozyDashboardScreen(),
            GoalsScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }
}
