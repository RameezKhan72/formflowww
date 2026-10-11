import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formflow/data/app_store.dart';
import 'package:formflow/domain/insights.dart';
import 'package:formflow/domain/profile.dart';
import 'package:formflow/domain/sample_data.dart';
import 'package:formflow/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

AppData signedIn({Goal goal = Goal.buildMuscle}) => AppData(
      onboarded: true,
      signedIn: true,
      ageConfirmed: true,
      profile: UserProfile(name: 'Rameez', age: 21, weightKg: 70, heightCm: 175, goal: goal, activityFactor: 1.55),
      benchmarkMs: 1.2,
      benchmarkTier: DeviceTier.standard,
      history: SampleData.history(loadCatalog(), DateTime.now()),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('signed-in user lands on the Workout tab and can visit every tab', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final app = await t.runAsync(() => buildApp(seed: signedIn(), useStore: false, splash: false));
    await t.pumpWidget(app!);
    await settle(t);
    expect(find.byKey(const Key('start_workout')), findsOneWidget);
    expect(find.textContaining('Your next workout'), findsWidgets);

    for (final tab in ['tab_routines', 'tab_exercises', 'tab_nutrition', 'tab_progress', 'tab_workout']) {
      await t.tap(find.byKey(Key(tab)));
      await settle(t, 400);
      expect(t.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('nutrition shows the TC-29 calorie target for cutting', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final app = await t.runAsync(() => buildApp(seed: signedIn(goal: Goal.cutting), useStore: false, splash: false));
    await t.pumpWidget(app!);
    await settle(t);
    await t.tap(find.byKey(const Key('tab_nutrition')));
    await settle(t, 800);
    final kcal = t.widget<Text>(find.byKey(const Key('kcal_target')));
    expect(int.parse(kcal.data!), closeTo(2232, 1));
  });

  testWidgets('declining the age gate blocks onboarding (TC-28)', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final app = await t.runAsync(() => buildApp(seed: const AppData(), useStore: false, splash: false));
    await t.pumpWidget(app!);
    await settle(t);
    expect(find.text('Your pocket form coach'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await settle(t);
    await t.tap(find.byKey(const Key('age_no')));
    await settle(t, 300);
    expect(find.textContaining('designed for adults'), findsOneWidget);
    final btn = t.widget<FilledButton>(find.byKey(const Key('onboarding_continue')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('sign-up rejects an invalid email with a message (FR-AU-03)', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final app = await t.runAsync(() => buildApp(seed: const AppData(onboarded: true, ageConfirmed: true), useStore: false, splash: false));
    await t.pumpWidget(app!);
    await settle(t);
    await t.enterText(find.byKey(const Key('auth_name')), 'Rameez');
    await t.enterText(find.byKey(const Key('auth_email')), 'not-an-email');
    await t.enterText(find.byKey(const Key('auth_password')), '123456');
    await t.tap(find.byKey(const Key('auth_submit')));
    await settle(t);
    expect(find.textContaining("doesn't look right"), findsOneWidget);
  });
}
