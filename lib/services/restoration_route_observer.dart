import 'package:flutter/material.dart';
import 'restoration_service.dart';

/// Custom RouteObserver that tracks route changes for state restoration
class RestorationRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _saveRouteForRestoration(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _saveRouteForRestoration(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _saveRouteForRestoration(previousRoute);
    }
  }

  /// Save the current route for restoration
  void _saveRouteForRestoration(Route<dynamic> route) {
    if (route.settings.name != null) {
      final routeName = route.settings.name!;

      // Don't save certain routes that shouldn't be restored
      // (like auth screens or the initial loading screen)
      final excludedRoutes = [
        '/',
        '/sign-in',
        '/sign-up',
        '/onboarding/splash',
      ];

      if (!excludedRoutes.contains(routeName)) {
        // Extract arguments if they're a Map
        Map<String, dynamic>? args;
        if (route.settings.arguments is Map<String, dynamic>) {
          args = route.settings.arguments as Map<String, dynamic>;
        }

        RestorationService.saveRoute(routeName, arguments: args);
      }
    }
  }
}
