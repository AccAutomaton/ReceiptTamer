import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _sourceCommit = 'ce04b3c6457f444645a4bd6cca98d5e71707115d';
const _manifestPath = 'test/ui_contract/fixtures/ce04b3c_source_hashes.json';
const _sheetWrapperName = 'showGlassContentBottomSheet';
const _ce04SheetFunctionName = 'showModalBottomSheet';
const _canonicalNormalization =
    'crlf_to_lf_trim_line_end_whitespace_and_canonicalize_approved_sheet_wrapper';

const _approvedSheetWrapperCounts = <String, int>{
  'lib/presentation/screens/orders/order_edit_screen.dart': 2,
  'lib/presentation/screens/orders/order_detail_screen.dart': 1,
  'lib/presentation/screens/invoices/invoice_edit_screen.dart': 2,
};

const _directoryScopes = <String>[
  'lib/presentation/screens',
  'lib/presentation/providers',
  'lib/presentation/widgets/order',
  'lib/presentation/widgets/invoice',
  'lib/presentation/widgets/settings',
];

const _singleFileScopes = <String>{
  'lib/presentation/widgets/main_shell.dart',
  'lib/router/app_router.dart',
};

void main() {
  late Map<String, dynamic> manifest;
  late Map<String, String> expectedHashes;

  setUpAll(() {
    manifest =
        jsonDecode(File(_manifestPath).readAsStringSync())
            as Map<String, dynamic>;
    expectedHashes = (manifest['files'] as Map<String, dynamic>).map(
      (path, hash) => MapEntry(path, hash as String),
    );
  });

  test('ce04b3c 内容与功能源契约记录完整基线信息', () {
    expect(manifest['schemaVersion'], 2);
    expect(manifest['sourceCommit'], _sourceCommit);
    expect(manifest['algorithm'], 'fnv1a64_utf8');
    expect(manifest['normalization'], _canonicalNormalization);
    expect(manifest['canonicalization'], {
      'from': _sheetWrapperName,
      'to': _ce04SheetFunctionName,
      'occurrences': _approvedSheetWrapperCounts,
    });
    expect(expectedHashes, hasLength(46));
    expect(
      _approvedSheetWrapperCounts.keys.every(expectedHashes.containsKey),
      isTrue,
      reason: '受控视觉迁移文件必须仍属于 ce04b3c 哈希保护集合。',
    );
    expect(
      expectedHashes.keys.where((path) => path.contains('/common/')),
      isEmpty,
      reason: 'common 是视觉换肤边界，不应被 ce04 内容源契约冻结。',
    );
  });

  test('受保护的内容与功能源文件集合保持 ce04b3c 不变', () {
    final actualFiles = _discoverProtectedDartFiles();
    final expectedFiles = expectedHashes.keys.toSet();

    expect(
      actualFiles,
      expectedFiles,
      reason: _fileSetDifference(expectedFiles, actualFiles),
    );
  });

  test('受保护文件标准化后的 FNV-1a 64 哈希保持 ce04b3c 不变', () {
    final mismatches = <String>[];

    for (final entry in expectedHashes.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) {
        mismatches.add('${entry.key}: 文件不存在');
        continue;
      }

      String normalized;
      try {
        normalized = _normalizeSource(entry.key, file.readAsStringSync());
      } on StateError catch (error) {
        mismatches.add('${entry.key}: ${error.message}');
        continue;
      }
      final actualHash = _fnv1a64Hex(normalized);
      if (actualHash != entry.value) {
        mismatches.add(
          '${entry.key}: expected ${entry.value}, actual $actualHash',
        );
      }
    }

    expect(
      mismatches,
      isEmpty,
      reason:
          '这些文件承载 ce04b3c 的页面功能、内容或文案；视觉换肤应改在 common 组件与主题层。\n'
          '${mismatches.join('\n')}',
    );
  });
}

Set<String> _discoverProtectedDartFiles() {
  final files = <String>{..._singleFileScopes};

  for (final scope in _directoryScopes) {
    final directory = Directory(scope);
    if (!directory.existsSync()) {
      continue;
    }

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(_toRepositoryPath(entity.path));
      }
    }
  }

  return files;
}

String _toRepositoryPath(String path) {
  final root = Directory.current.absolute.path;
  final absolute = File(path).absolute.path;
  final relative = absolute.startsWith(root)
      ? absolute.substring(root.length).replaceFirst(RegExp(r'^[\\/]'), '')
      : path;
  return relative.replaceAll('\\', '/');
}

String _normalizeSource(String path, String source) {
  final lfOnly = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  var normalized = lfOnly
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'[ \t]+$'), ''))
      .join('\n');

  final actualCount = _literalCount(normalized, _sheetWrapperName);
  final expectedCount = _approvedSheetWrapperCounts[path];
  if (expectedCount == null) {
    if (actualCount != 0) {
      throw StateError('未经批准使用 $_sheetWrapperName，共 $actualCount 处。');
    }
    return normalized;
  }

  if (actualCount != expectedCount) {
    throw StateError(
      '$_sheetWrapperName 应精确出现 $expectedCount 处，实际 $actualCount 处。',
    );
  }

  normalized = normalized.replaceAll(_sheetWrapperName, _ce04SheetFunctionName);
  return normalized;
}

int _literalCount(String source, String literal) {
  var count = 0;
  var start = 0;
  while (true) {
    final index = source.indexOf(literal, start);
    if (index < 0) return count;
    count++;
    start = index + literal.length;
  }
}

String _fnv1a64Hex(String source) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask64 = (BigInt.one << 64) - BigInt.one;

  for (final byte in utf8.encode(source)) {
    hash ^= BigInt.from(byte);
    hash = (hash * prime) & mask64;
  }

  return hash.toRadixString(16).padLeft(16, '0');
}

String _fileSetDifference(Set<String> expected, Set<String> actual) {
  final missing = expected.difference(actual).toList()..sort();
  final extra = actual.difference(expected).toList()..sort();
  return [
    'ce04b3c 受保护文件集合发生变化。',
    '缺失文件: ${missing.isEmpty ? '(无)' : missing.join(', ')}',
    '额外文件: ${extra.isEmpty ? '(无)' : extra.join(', ')}',
  ].join('\n');
}
