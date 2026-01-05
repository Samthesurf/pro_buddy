import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/progress_streak_cubit.dart';
import '../bloc/onboarding_preferences_cubit.dart';
import '../bloc/daily_usage_summary_cubit.dart';
import '../bloc/usage_history_cubit.dart';
import '../core/cozy_theme.dart';
import '../widgets/navigation_shell.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'goals_screen.dart';

/// Main screen with default Material theme (supports light/dark via system).
/// For the warm cozy theme, use [CozyMainScreen] instead.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Provide dashboard-specific cubits at this level
    return MultiBlocProvider(
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
        // In light mode, enforce the 'Elegant Brown' cozy aesthetic.
        // In dark mode, let the theme handle it (null) to avoid a white bar.
        backgroundColor: isDark ? null : CozyColors.surface,
        indicatorColor: isDark ? null : CozyColors.navigationIndicator,
        screens: const [DashboardScreen(), GoalsScreen(), SettingsScreen()],
      ),
    );
  }
}
