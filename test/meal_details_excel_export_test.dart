import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/data/models/daily_meal_details.dart';
import 'package:receipt_tamer/data/services/meal_details_export_service.dart';

void main() {
  test('project depends on XlsIO and pdfrx instead of the excel package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, isNot(contains(RegExp(r'^\s*excel:', multiLine: true))));
    expect(
      pubspec,
      contains(RegExp(r'^\s*syncfusion_flutter_xlsio:', multiLine: true)),
    );
    expect(pubspec, contains(RegExp(r'^\s*pdfrx:', multiLine: true)));
    expect(pubspec, contains(RegExp(r'^\s*archive:\s*\^4\.', multiLine: true)));
  });

  test('builds project-style meal details xlsx bytes', () {
    final bytes = MealDetailsExportService.buildExcelBytes(
      items: const [
        DailyMealDetails(
          date: '2026-05-21',
          breakfastPaid: 10,
          breakfastInvoice: 9.5,
          lunchPaid: 22.34,
          lunchInvoice: 20,
        ),
      ],
    );

    expect(bytes, isNotEmpty);

    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookXml = _readZipText(archive, 'xl/workbook.xml');
    final sharedStringsXml = _readZipText(archive, 'xl/sharedStrings.xml');
    final sheetXml = _readZipText(archive, 'xl/worksheets/sheet1.xml');
    final stylesXml = _readZipText(archive, 'xl/styles.xml');

    expect(workbookXml, contains('用餐明细'));
    expect(sharedStringsXml, contains('日期'));
    expect(sharedStringsXml, contains('早餐实付'));
    expect(sharedStringsXml, contains('2026年05月21日'));
    expect(sharedStringsXml, contains('总计'));
    expect(sheetXml, contains('22.34'));
    expect(stylesXml, contains('horizontal="center"'));
    expect(stylesXml, contains('horizontal="right"'));
    expect(stylesXml, contains('numFmtId="2"'));
  });
}

String _readZipText(Archive archive, String name) {
  return utf8.decode(
    archive.files.singleWhere((file) => file.name == name).content,
  );
}
