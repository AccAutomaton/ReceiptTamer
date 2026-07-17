import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/screens/export/export_options_screen.dart';
import 'package:receipt_tamer/presentation/widgets/common/app_notice.dart';

void main() {
  testWidgets('custom export toggles expose checked semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExportOptionsScreen(invoiceIds: [1], orderIds: [1]),
        ),
      ),
    );
    await tester.pump();

    final mealRemark = find.bySemanticsLabel('添加用餐证明备注');
    final invoiceTime = find.bySemanticsLabel('标注订单时间');
    final invoiceRemark = find.bySemanticsLabel('添加发票备注');

    expect(mealRemark, findsOneWidget);
    expect(invoiceTime, findsOneWidget);
    expect(invoiceRemark, findsOneWidget);
    expect(
      tester.getSemantics(mealRemark),
      matchesSemantics(
        label: '添加用餐证明备注',
        isButton: true,
        hasTapAction: true,
        hasCheckedState: true,
        isChecked: false,
      ),
    );
    expect(
      tester.getSemantics(invoiceTime),
      matchesSemantics(
        label: '标注订单时间',
        isButton: true,
        hasTapAction: true,
        hasCheckedState: true,
        isChecked: false,
      ),
    );

    await tester.tap(invoiceTime);
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel('标注订单时间')),
      matchesSemantics(
        label: '标注订单时间',
        isButton: true,
        hasTapAction: true,
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('partial export error appears before saved-files route returns', (
    tester,
  ) async {
    late OverlayState overlay;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            overlay = Overlay.of(context, rootOverlay: true);
            return const Scaffold(body: Text('export host'));
          },
        ),
      ),
    );

    final routeCompleter = Completer<void>();
    var helperCompleted = false;
    final helperFuture = showSavedFilesAndReportExportErrors(
      overlay: overlay,
      showSavedFiles: () => routeCompleter.future,
      errors: const ['发票：缺少附件，无法导出'],
    )..then((_) => helperCompleted = true);

    await tester.pump();

    expect(find.text('发票：缺少附件，无法导出'), findsOneWidget);
    expect(helperCompleted, isFalse);

    routeCompleter.complete();
    await helperFuture;
    AppNotice.dismiss();
    await tester.pump();
  });
}
