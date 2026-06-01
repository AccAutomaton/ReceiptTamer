import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('third-party shader glass package is not used by the app', () {
    final packageName = ['liquid', '_glass', '_easy'].join();
    final shellPrefix = ['Liquid', 'Glass', 'Easy'].join();
    final references = <String>[];

    final pubspec = File('pubspec.yaml').readAsStringSync();
    if (pubspec.contains(packageName)) {
      references.add('pubspec.yaml');
    }

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains(packageName) || source.contains(shellPrefix)) {
        references.add(entity.path);
      }
    }

    expect(references, isEmpty);
  });
}
