import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../exercises/exercises_tab.dart';
import '../nutrition/nutrition_tab.dart';
import '../progress/progress_tab.dart';
import '../routines/routines_tab.dart';
import '../settings/profile_sheet.dart';
import '../workout/workout_tab.dart';

final tabIndexProvider = StateProvider<int>((ref) => 2);

/// Five tabs with Workout as home (PRD 3.2); profile avatar in the top bar.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const tabs = ['Routines', 'Exercises', 'Workout', 'Nutrition', 'Progress'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);
    final name = ref.watch(appProvider).profile.name;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const FormFlowLogo(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              key: const Key('avatar'),
              customBorder: const CircleBorder(),
              onTap: () => showProfileSheet(context),
              child: Semantics(
                label: 'Profile and settings',
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: FF.accentSoft,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(color: FF.text, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: const [RoutinesTab(), ExercisesTab(), WorkoutTab(), NutritionTab(), ProgressTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(tabIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(key: Key('tab_routines'), icon: Icon(Icons.format_list_bulleted), label: 'Routines'),
          NavigationDestination(key: Key('tab_exercises'), icon: Icon(Icons.accessibility_new), label: 'Exercises'),
          NavigationDestination(key: Key('tab_workout'), icon: Icon(Icons.fitness_center), label: 'Workout'),
          NavigationDestination(key: Key('tab_nutrition'), icon: Icon(Icons.restaurant), label: 'Nutrition'),
          NavigationDestination(key: Key('tab_progress'), icon: Icon(Icons.insights), label: 'Progress'),
        ],
      ),
    );
  }
}
