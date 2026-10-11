import 'package:flutter/material.dart';

import '../domain/exercise.dart';
import 'mannequin.dart';

/// Realistic 3D exercise demonstration (asset A3, PRD 4.1 option 3:
/// pre-rendered loops). The anatomical figure is posed with the same
/// keyframes as the 2D demonstrator and rendered in Blender by
/// tool/anatomy/pose_render.py; worked muscles are red. Each exercise is a
/// small looping animated WebP, so no 3D engine runs on the phone.
class Exercise3DView extends StatelessWidget {
  final ExerciseDef def;
  final bool animate;
  const Exercise3DView({super.key, required this.def, this.animate = true});

  static String asset(String id) => 'assets/exercise_anim/$id.webp';

  /// Kept for call sites that choose between 3D and 2D.
  static bool get supported => true;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final path = (animate && !reduce) ? asset(def.id) : 'assets/thumbs/${def.id}.webp';
    return Semantics(
      label: '3D demonstration of ${def.name}',
      image: true,
      child: Image.asset(
        path,
        key: ValueKey(path),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => ExerciseDemo(def: def, animate: animate),
      ),
    );
  }
}
