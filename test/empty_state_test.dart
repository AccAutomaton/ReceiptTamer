import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/widgets/common/empty_state.dart';

void main() {
  testWidgets('EmptyState action can omit an unrelated leading icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.error_outline,
            title: '加载失败',
            actionLabel: '重试',
            actionIcon: null,
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.widgetWithText(ElevatedButton, '重试'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
