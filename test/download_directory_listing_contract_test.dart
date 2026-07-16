import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 归档列表只返回当前目录直属文件', () {
    final source = File(
      'android/app/src/main/kotlin/com/acautomaton/receipt/tamer/DownloadHelper.kt',
    ).readAsStringSync();
    final methodStart = source.indexOf('private fun listFilesWithMediaStore');
    final methodEnd = source.indexOf(
      'private fun listFilesWithTraditionalMethod',
      methodStart,
    );

    expect(methodStart, greaterThanOrEqualTo(0));
    expect(methodEnd, greaterThan(methodStart));

    final method = source.substring(methodStart, methodEnd);
    expect(method, contains('RELATIVE_PATH} IN (?, ?)'));
    expect(method, contains('MIME_TYPE} IS NOT NULL'));
    expect(method, contains('arrayOf(normalizedPath, "\$normalizedPath/")'));
    expect(method, isNot(contains('RELATIVE_PATH} LIKE ?')));
    expect(method, isNot(contains('"\$relativePath%"')));
  });
}
