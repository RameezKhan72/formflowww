import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'state/app_state.dart';
import 'widgets/muscle_map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(await buildApp());
}

/// Builds the app with loaded data. [seed] lets tests and screenshot runs
/// start from a prepared state.
Future<Widget> buildApp({AppData? seed, bool useStore = true, bool splash = true}) async {
  final catalog = await ExerciseRepository.load();
  AppStore? store;
  if (useStore) {
    try {
      store = await AppStore.open();
    } catch (_) {
      store = null; // storage unavailable: run in memory (NFR-RL-01)
    }
  }
  final data = seed ?? store?.load() ?? const AppData();
  if (seed != null) await store?.save(seed);
  try {
    await BodyMapData.load();
  } catch (_) {}
  final controller = AppController(data, catalog, store: store);
  return ProviderScope(
    overrides: [
      catalogProvider.overrideWithValue(catalog),
      appProvider.overrideWith((ref) => controller),
    ],
    child: FormFlowApp(showSplash: splash),
  );
}
