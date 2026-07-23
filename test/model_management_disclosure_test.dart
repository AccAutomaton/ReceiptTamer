import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:receipt_tamer/presentation/screens/settings/model_management_screen.dart';

void main() {
  testWidgets('模型设置就地说明手工、本地与云端的速度隐私和成本', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ModelManagementScreen())),
    );
    await tester.pump();

    expect(find.text('选择适合你的录入方式'), findsOneWidget);
    expect(find.text('纯手工'), findsOneWidget);
    expect(find.text('本地模型'), findsWidgets);
    expect(find.text('云端模型'), findsOneWidget);
    expect(find.textContaining('数据不离开设备'), findsOneWidget);
    expect(find.textContaining('全程本机处理'), findsOneWidget);
    expect(find.textContaining('内容发送至指定模型供应商'), findsOneWidget);
    expect(find.textContaining('可能产生服务商费用'), findsOneWidget);
  });
}
