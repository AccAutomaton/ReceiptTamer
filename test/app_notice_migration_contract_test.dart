import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('生产代码不再创建底部 SnackBar 或其他 Toast 提示', () {
    final forbidden = <RegExp>[
      RegExp(r'\bSnackBar\s*\('),
      RegExp(r'\bshowSnackBar\s*\('),
      RegExp(r'\bScaffoldMessenger\b'),
      RegExp(r'\bshowMaterialBanner\s*\('),
      RegExp(r'\bFluttertoast\b'),
      RegExp(r'\bToast\.makeText\s*\('),
    ];
    final violations = <String>[];

    final dartFiles =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        if (forbidden.any((pattern) => pattern.hasMatch(lines[index]))) {
          violations.add('${file.path}:${index + 1}: ${lines[index].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '短时反馈必须统一使用顶部 AppNotice：\n${violations.join('\n')}',
    );
  });
}
