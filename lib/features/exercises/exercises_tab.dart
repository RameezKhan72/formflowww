import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/exercise.dart';
import '../../state/app_state.dart';
import '../../widgets/exercise_row.dart';
import 'exercise_detail_screen.dart';

/// Exercise library with search, filters and favourites (FR-EX-03).
class ExercisesTab extends ConsumerStatefulWidget {
  const ExercisesTab({super.key});

  @override
  ConsumerState<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<ExercisesTab> {
  String _q = '';
  String? _type;
  String? _equipment;
  String? _muscle;
  int? _level;
  bool _favOnly = false;

  List<ExerciseDef> _filter(ExerciseCatalog cat, Set<String> favs) {
    return cat.exercises.where((e) {
      if (_q.isNotEmpty &&
          !e.name.toLowerCase().contains(_q.toLowerCase()) &&
          !e.muscles.keys.any((m) => m.contains(_q.toLowerCase())) &&
          !e.group.contains(_q.toLowerCase())) {
        return false;
      }
      if (_type != null && e.type != _type) return false;
      if (_equipment != null && !e.equipment.contains(_equipment)) return false;
      if (_muscle != null && (e.muscles[_muscle] ?? 0) < 0.15) return false;
      if (_level != null && e.level != _level) return false;
      if (_favOnly && !favs.contains(e.id)) return false;
      return true;
    }).toList();
  }

  Future<void> _pick<T>(String title, List<(T, String)> options, T? current, ValueChanged<T?> onPick) async {
    final r = await showModalBottomSheet<(bool, T?)>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ListTile(title: const Text('Any'), onTap: () => Navigator.pop(c, (true, null))),
          for (final o in options)
            ListTile(
              title: Text(o.$2),
              trailing: o.$1 == current ? const Icon(Icons.check, color: FF.accent) : null,
              onTap: () => Navigator.pop(c, (true, o.$1)),
            ),
        ]),
      ),
    );
    if (r != null && r.$1) setState(() => onPick(r.$2));
  }

  Widget _filterButton(String label, IconData icon, bool active, VoidCallback onTap) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: active ? FF.accentSoft : FF.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final cat = app.catalog;
    final favs = app.data.favourites;
    final list = _filter(cat, favs);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: const Key('exercise_search'),
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Favourites',
            onPressed: () => setState(() => _favOnly = !_favOnly),
            icon: Icon(_favOnly ? Icons.star : Icons.star_border, color: _favOnly ? FF.warn : FF.muted),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(children: [
          _filterButton('Type', Icons.category_outlined, _type != null,
              () => _pick<String>('Type', const [('bodyweight', 'Bodyweight'), ('strength', 'Strength'), ('isometric', 'Isometric')], _type, (v) => _type = v)),
          _filterButton('Equipment', Icons.fitness_center, _equipment != null,
              () => _pick<String>('Equipment', ExerciseCatalog.equipmentTypes.map((e) => (e, e[0].toUpperCase() + e.substring(1))).toList(), _equipment, (v) => _equipment = v)),
          _filterButton('Muscles', Icons.accessibility, _muscle != null,
              () => _pick<String>('Muscles', MuscleIds.all.map((m) => (m, MuscleIds.label(m))).toList(), _muscle, (v) => _muscle = v)),
          _filterButton('Level', Icons.signal_cellular_alt, _level != null,
              () => _pick<int>('Level', List.generate(5, (i) => (i + 1, 'Level ${i + 1}')), _level, (v) => _level = v)),
        ]),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: list.isEmpty
            ? const Center(child: Text('No exercises match these filters', style: TextStyle(color: FF.muted)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = list[i];
                  final fav = favs.contains(e.id);
                  return ExerciseRow(
                    key: Key('ex_${e.id}'),
                    def: e,
                    showBadge: true,
                    subtitle: MuscleIds.label(e.primaryMuscle),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseDetailScreen(def: e))),
                    trailing: IconButton(
                      tooltip: fav ? 'Remove favourite' : 'Add favourite',
                      onPressed: () => app.toggleFavourite(e.id),
                      icon: Icon(fav ? Icons.star : Icons.star_border, color: fav ? FF.warn : FF.muted),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}
