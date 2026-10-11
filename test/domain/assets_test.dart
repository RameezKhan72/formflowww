import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Checks the realistic anatomy assets rendered by tool/anatomy/.
void main() {
  final cat = loadCatalog();

  test('every exercise has a 3D animation and a thumbnail', () {
    for (final e in cat.exercises) {
      final anim = File('assets/exercise_anim/${e.id}.webp');
      final thumb = File('assets/thumbs/${e.id}.webp');
      expect(anim.existsSync(), isTrue, reason: e.id);
      expect(thumb.existsSync(), isTrue, reason: e.id);
      final head = anim.readAsBytesSync().sublist(0, 12);
      expect(ascii.decode(head.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(head.sublist(8, 12)), 'WEBP');
    }
  });

  test('the body map covers all 14 muscles', () {
    final meta = jsonDecode(File('assets/anatomy3d/meta.json').readAsStringSync()) as Map<String, dynamic>;
    final groups = (meta['groups'] as List).cast<String>();
    expect(groups, hasLength(14));
    final views = meta['views'] as Map<String, dynamic>;
    for (final g in groups) {
      final inFront = (views['front']['boxes'] as Map).containsKey(g);
      final inBack = (views['back']['boxes'] as Map).containsKey(g);
      expect(inFront || inBack, isTrue, reason: g);
    }
    for (final v in ['front', 'back']) {
      expect(File('assets/anatomy3d/body_$v.webp').existsSync(), isTrue);
      expect(File('assets/anatomy3d/id_$v.png').existsSync(), isTrue);
    }
  });

  test('media stays within the PRD budget (under 15 MB)', () {
    var total = 0;
    for (final dir in ['assets/anatomy3d', 'assets/exercise_anim', 'assets/thumbs']) {
      for (final f in Directory(dir).listSync().whereType<File>()) {
        total += f.lengthSync();
      }
    }
    expect(total, lessThan(15 * 1024 * 1024));
  });
}
