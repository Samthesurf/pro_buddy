import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';
import '../core/routes.dart';
import '../services/onboarding_storage.dart';

/// Shared navigation configuration for the app's main tabs.
/// This defines the tabs and their properties regardless of theme.
class AppNavigation {
  const AppNavigation._();

  /// Navigation destinations that appear in the bottom bar
  static const List<NavigationDestination> destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.flag_outlined),
      selectedIcon: Icon(Icons.flag_rounded),
      label: 'Goals',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];
}

/// Builder function type for creating screen widgets
typedef ScreenBuilder = Widget Function(BuildContext context);

/// Navigation shell that handles the common navigation logic.
/// Works with any theme (light, dark, cozy, etc.)
class NavigationShell extends StatelessWidget {
  const NavigationShell({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.screens,
    this.backgroundColor,
    this.indicatorColor,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> screens;

  /// Optional background color override (null uses Theme default)
  final Color? backgroundColor;

  /// Optional indicator color override (null uses Theme default)
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (state.status == AuthStatus.unauthenticated) {
          final hasSeenOnboarding = await OnboardingStorage.hasSeenOnboarding();
          if (!context.mounted) return;

          Navigator.of(context).pushNamedAndRemoveUntil(
            hasSeenOnboarding ? AppRoutes.signIn : AppRoutes.onboardingSplash,
            (route) => false,
          );
        }
      },
      child: Scaffold(
        body: IndexedStack(index: currentIndex, children: screens),
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
            backgroundColor: backgroundColor ?? theme.colorScheme.surface,
            indicatorColor:
                indicatorColor ??
                theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            destinations: AppNavigation.destinations,
          ),
        ),
      ),
    );
  }
}

/// Common BLoC providers needed for the main screens
class MainScreenProviders extends StatelessWidget {
  const MainScreenProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Import dynamically to avoid circular dependencies
    return child;
  }
}
