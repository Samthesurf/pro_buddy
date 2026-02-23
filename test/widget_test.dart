import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_buddy/bloc/theme_cubit.dart';
import 'package:pro_buddy/widgets/theme_switcher.dart';

void main() {
  testWidgets('ThemeSwitcher toggles to dark mode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ThemeCubit(),
        child: const MaterialApp(home: Scaffold(body: ThemeSwitcher())),
      ),
    );

    expect(find.text('Cozy'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump();

    final element = tester.element(find.byType(ThemeSwitcher));
    expect(element.read<ThemeCubit>().state, ThemeMode.dark);
  });
}
