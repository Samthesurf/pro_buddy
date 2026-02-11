import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pro_buddy/bloc/navigation_cubit.dart';

class MockStorage extends Mock implements Storage {}

void main() {
  group('NavigationCubit', () {
    late Storage storage;

    setUp(() {
      storage = MockStorage();
      when(
        () => storage.write(any(), any<dynamic>()),
      ).thenAnswer((_) async {});
      HydratedBloc.storage = storage;
    });

    test('initial state is correct', () {
      final cubit = NavigationCubit();
      expect(cubit.state.lastRoute, isNull);
      expect(cubit.state.lastArgs, isNull);
    });

    test('setLastRoute updates state', () {
      final cubit = NavigationCubit();
      cubit.setLastRoute('/test', args: {'id': 1});
      expect(cubit.state.lastRoute, '/test');
      expect(cubit.state.lastArgs, {'id': 1});
      expect(cubit.state.timestamp, isNotNull);
    });

    test('fromJson restores valid state', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final json = {
        'lastRoute': '/restored',
        'lastArgs': null,
        'timestamp': now,
      };
      
      final cubit = NavigationCubit();
      final state = cubit.fromJson(json);
      
      expect(state, isNotNull);
      expect(state!.lastRoute, '/restored');
    });

    test('fromJson discards expired state (> 14 days)', () {
      // 15 days ago
      final oldTime = DateTime.now().subtract(const Duration(days: 15)).millisecondsSinceEpoch;
      final json = {
        'lastRoute': '/old',
        'lastArgs': null,
        'timestamp': oldTime,
      };
      
      final cubit = NavigationCubit();
      final state = cubit.fromJson(json);
      
      expect(state, isNull);
    });

    test('fromJson keeps valid state (< 14 days)', () {
      // 13 days ago
      final validTime = DateTime.now().subtract(const Duration(days: 13)).millisecondsSinceEpoch;
      final json = {
        'lastRoute': '/valid',
        'lastArgs': null,
        'timestamp': validTime,
      };
      
      final cubit = NavigationCubit();
      final state = cubit.fromJson(json);
      
      expect(state, isNotNull);
      expect(state!.lastRoute, '/valid');
    });
  });
}
