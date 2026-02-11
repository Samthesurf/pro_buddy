import 'package:hydrated_bloc/hydrated_bloc.dart';

class NavigationState {
  final String? lastRoute;
  final Map<String, dynamic>? lastArgs;
  final int? timestamp;

  NavigationState({this.lastRoute, this.lastArgs, this.timestamp});

  Map<String, dynamic> toJson() {
    return {
      'lastRoute': lastRoute,
      'lastArgs': lastArgs,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory NavigationState.fromJson(Map<String, dynamic> json) {
    return NavigationState(
      lastRoute: json['lastRoute'] as String?,
      lastArgs: json['lastArgs'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as int?,
    );
  }
}

class NavigationCubit extends HydratedCubit<NavigationState> {
  NavigationCubit() : super(NavigationState());

  void setLastRoute(String route, {Map<String, dynamic>? args}) {
    emit(NavigationState(
      lastRoute: route,
      lastArgs: args,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void clearRoute() {
    emit(NavigationState());
  }

  @override
  NavigationState? fromJson(Map<String, dynamic> json) {
    final state = NavigationState.fromJson(json);
    
    // Check if cache is older than 14 days
    if (state.timestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - state.timestamp!;
      // 14 days in milliseconds: 14 * 24 * 60 * 60 * 1000 = 1209600000
      if (diff > 1209600000) {
        return null; // Discard cache
      }
    }
    
    return state;
  }

  @override
  Map<String, dynamic>? toJson(NavigationState state) {
    return state.toJson();
  }
}
