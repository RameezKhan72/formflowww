import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/exercise.dart';
import '../../domain/insights.dart';
import '../../domain/routine.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/exercise_row.dart';
import '../../widgets/exercise_3d.dart';
import '../../widgets/mannequin.dart';
import '../tracking/workout_run_screen.dart';

/// Exercise detail (FR-EX-04): looping demonstration, muscles worked,
/// setup tips, camera placement diagram, common mistakes, Start / Demo.
class ExerciseDetailScreen extends ConsumerWidget {
  final ExerciseDef def;
  const ExerciseDetailScreen({super.key, required this.def});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final animate = app.data.tier.animatedDemos && !app.settings.reduceMotion;
    final share = RoutineMath.exerciseShare(def);
    final single = Routine(id: 'single_${def.id}', name: def.name, items: [RoutineItem.defaults(def)]);
    return Scaffold(
      appBar: AppBar(title: Text(def.name), actions: [
        IconButton(
          onPressed: () => app.toggleFavourite(def.id),
          icon: Icon(app.data.favourites.contains(def.id) ? Icons.star : Icons.star_border, color: FF.warn),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _DemoPanel(def: def, animate: animate, prefer3d: true),
          const SizedBox(height: 12),
          Row(children: [
            LevelBars(def.level),
            const SizedBox(width: 8),
            Text('Level ${def.level}', style: const TextStyle(color: FF.muted)),
            const SizedBox(width: 12),
            StatusBadge(validated: def.isValidated),
            const Spacer(),
            Text(def.targetLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Muscles worked',
            icon: Icons.accessibility_new,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: share.map((m) => MusclePercent(muscle: m.key, percent: m.value)).toList()),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Setup tips',
            icon: Icons.lightbulb_outline,
            child: Column(
              children: def.tips
                  .map((t) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle, color: FF.good, size: 20),
                        title: Text(t),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Camera placement',
            icon: Icons.videocam_outlined,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(painter: _CameraDiagram(front: def.views.first == CameraView.front)),
              ),
              const SizedBox(height: 8),
              Text(def.cameraTip, style: const TextStyle(color: FF.muted)),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Common mistakes',
            icon: Icons.report_gmailerrorred,
            child: Column(
              children: def.mistakes
                  .map((t) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.error_outline, color: FF.bad, size: 20),
                        title: Text(t),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('start_camera'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => WorkoutRunScreen(routine: single))),
            icon: const Icon(Icons.videocam),
            label: const Text('Start with camera'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('start_demo'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => WorkoutRunScreen(routine: single, demo: true))),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Demo mode (no camera)'),
          ),
        ],
      ),
    );
  }
}

/// Demonstration panel with a 3D / 2D switch (FR-DM-05). 3D is the default
/// on Standard and High devices; Lite and reduced motion start in 2D.
class _DemoPanel extends StatefulWidget {
  final ExerciseDef def;
  final bool animate;
  final bool prefer3d;
  const _DemoPanel({required this.def, required this.animate, required this.prefer3d});

  @override
  State<_DemoPanel> createState() => _DemoPanelState();
}

class _DemoPanelState extends State<_DemoPanel> {
  late bool _3d = widget.prefer3d;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FF.radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3264), Color(0xFF10142C)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(8, 44, 8, 8), child: _3d ? Exercise3DView(def: widget.def, animate: widget.animate) : ExerciseDemo(def: widget.def, animate: widget.animate))),
        Positioned(
          left: 10,
          top: 10,
          child: SegmentedButton<bool>(
            key: const Key('demo_view_toggle'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: true, label: Text('3D'), icon: Icon(Icons.view_in_ar, size: 16)),
              ButtonSegment(value: false, label: Text('2D')),
            ],
            selected: {_3d},
            onSelectionChanged: (s) => setState(() => _3d = s.first),
          ),
        ),
      ]),
    );
  }
}

/// Simple diagram: phone on the floor 2 m from the person, side or front.
class _CameraDiagram extends CustomPainter {
  final bool front;
  _CameraDiagram({required this.front});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 12;
    final line = Paint()
      ..color = FF.outline
      ..strokeWidth = 2;
    canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), line);
    // phone
    final phone = RRect.fromRectAndRadius(Rect.fromLTWH(24, y - 54, 22, 40), const Radius.circular(4));
    canvas.drawRRect(phone, Paint()..color = FF.accent);
    canvas.drawCircle(Offset(35, y - 46), 3, Paint()..color = Colors.white);
    // person
    final px = size.width - 70;
    final body = Paint()
      ..color = FF.bodyFill
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(px, y - 80), 9, Paint()..color = FF.bodyFill);
    canvas.drawLine(Offset(px, y - 70), Offset(px, y - 36), body);
    canvas.drawLine(Offset(px, y - 36), Offset(px - (front ? 8 : 0), y - 2), body);
    canvas.drawLine(Offset(px, y - 36), Offset(px + (front ? 8 : 4), y - 2), body);
    canvas.drawLine(Offset(px, y - 64), Offset(px - (front ? 16 : 0), y - 40), body);
    canvas.drawLine(Offset(px, y - 64), Offset(px + (front ? 16 : 10), y - 42), body);
    // distance arrow
    final arrow = Paint()
      ..color = FF.muted
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(56, y - 30), Offset(px - 24, y - 30), arrow);
    final tp = TextPainter(
      text: TextSpan(text: front ? 'about 2 m, facing you' : 'about 2 m, side-on', style: const TextStyle(color: FF.muted, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((56 + px - 24) / 2 - tp.width / 2, y - 48));
  }

  @override
  bool shouldRepaint(covariant _CameraDiagram old) => old.front != front;
}
