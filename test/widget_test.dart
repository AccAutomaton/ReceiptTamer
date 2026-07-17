// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:receipt_tamer/app.dart';
import 'package:receipt_tamer/core/theme/app_design_tokens.dart';
import 'package:receipt_tamer/data/models/invoice.dart';
import 'package:receipt_tamer/data/models/llm_backend.dart';
import 'package:receipt_tamer/data/models/order.dart';
import 'package:receipt_tamer/data/models/uninvoiced_shop_summary.dart';
import 'package:receipt_tamer/data/repositories/invoice_repository.dart';
import 'package:receipt_tamer/data/repositories/order_repository.dart';
import 'package:receipt_tamer/data/services/llm_config_service.dart';
import 'package:receipt_tamer/presentation/providers/invoice_provider.dart';
import 'package:receipt_tamer/presentation/providers/order_provider.dart';
import 'package:receipt_tamer/presentation/widgets/common/glass_navigation_bar.dart';

void main() {
  const llmChannel = MethodChannel('com.acautomaton.receipt.tamer/llm');
  const shareMethodChannel = MethodChannel('receive_sharing_intent/messages');
  const shareEventChannel = MethodChannel(
    'receive_sharing_intent/events-media',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareMethodChannel, (call) async {
          if (call.method == 'getInitialMedia') return '[]';
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareEventChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(llmChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareMethodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareEventChannel, null);
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(_testApp(enableBackgroundInitialization: false));

    // Render one frame; background services are covered outside this smoke test.
    await tester.pump();

    // Verify that the home screen loads with the expected title.
    expect(find.text('首页'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('glass_nav_intake_action')),
      findsOneWidget,
    );
    expect(find.text('报销'), findsOneWidget);

    await _unmountApp(tester);
  });

  testWidgets('nested BACK pops normally and root BACK requires confirmation', (
    WidgetTester tester,
  ) async {
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_testApp(enableBackgroundInitialization: false));
    await tester.pump();

    void expectFrameworkAlwaysHandlesBack() {
      final frameworkBackCalls = platformCalls
          .where(
            (call) => call.method == 'SystemNavigator.setFrameworkHandlesBack',
          )
          .toList(growable: false);
      expect(frameworkBackCalls, isNotEmpty);
      expect(
        frameworkBackCalls.every((call) => call.arguments == true),
        isTrue,
      );
    }

    expectFrameworkAlwaysHandlesBack();

    await tester.tap(find.byKey(const ValueKey('home-settings-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('设置'), findsOneWidget);

    platformCalls.clear();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('首页'), findsNWidgets(2));
    expect(find.text('再次返回回到桌面'), findsNothing);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );
    expectFrameworkAlwaysHandlesBack();

    platformCalls.clear();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('再次返回回到桌面'), findsOneWidget);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      hasLength(1),
    );

    await _unmountApp(tester);
  });

  testWidgets('Intake action opens the receipt intake desk', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(enableBackgroundInitialization: false));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('glass_nav_intake_action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('glass_add_sheet')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('glass_add_sheet')),
        matching: find.text('新增'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('glass_add_sheet')),
        matching: find.text('添加订单'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('glass_add_sheet')),
        matching: find.text('添加发票'),
      ),
      findsOneWidget,
    );

    await _unmountApp(tester);
  });

  testWidgets('Recent orders more switches the shell to the orders tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(enableBackgroundInitialization: false));
    await tester.pump();

    final more = find.byKey(const ValueKey('home-recent-orders-more'));
    for (var attempt = 0; attempt < 10 && more.evaluate().isEmpty; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(more, findsOneWidget);

    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('订单列表'), findsOneWidget);
    final navigation = tester.widget<GlassNavigationBar>(
      find.byType(GlassNavigationBar),
    );
    expect(navigation.selectedIndex, 1);

    await _unmountApp(tester);
  });

  testWidgets('App uses the morning-mist action palette', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(enableBackgroundInitialization: false));
    await tester.pump();

    final context = tester.element(find.byType(Scaffold).first);
    final colorScheme = Theme.of(context).colorScheme;

    expect(colorScheme.primary, AppPalette.actionPrimary);
    expect(colorScheme.surface, AppPalette.coldBackground);

    await _unmountApp(tester);
  });

  testWidgets('App preloads local model after startup when configured', (
    WidgetTester tester,
  ) async {
    await LlmConfigService().save(
      const LlmBackendConfig(backendType: LlmBackendType.localMnn),
    );
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(llmChannel, (call) async {
          calls.add(call.method);
          if (call.method == 'initialize') {
            return <String, dynamic>{
              'isLoading': false,
              'isInitialized': true,
              'archNotSupported': false,
            };
          }
          return null;
        });

    await tester.pumpWidget(_testApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(calls, contains('initialize'));

    await tester.pump(const Duration(milliseconds: 700));
    await _unmountApp(tester);
  });
}

Future<void> _unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

ProviderScope _testApp({bool enableBackgroundInitialization = true}) {
  return ProviderScope(
    overrides: [
      orderRepositoryProvider.overrideWithValue(_FakeOrderRepository()),
      invoiceRepositoryProvider.overrideWithValue(_FakeInvoiceRepository()),
    ],
    child: App(enableBackgroundInitialization: enableBackgroundInitialization),
  );
}

class _FakeOrderRepository extends OrderRepository {
  @override
  Future<List<Order>> getAll({int? limit, int? offset}) async => const [];

  @override
  Future<int> getCount() async => 0;

  @override
  Future<List<Order>> getRecentlyCreated({int limit = 10}) async => const [];

  @override
  Future<List<UninvoicedShopSummary>> getUninvoicedShopSummaries({
    DateTime? startDate,
    DateTime? endDate,
  }) async => const [];

  @override
  Future<Map<int, int>> getInvoiceCountsForOrders(List<int> orderIds) async =>
      const {};
}

class _FakeInvoiceRepository extends InvoiceRepository {
  @override
  Future<List<Invoice>> getAll({int? limit, int? offset}) async => const [];

  @override
  Future<int> getCount() async => 0;

  @override
  Future<List<Invoice>> getRecentlyCreated({int limit = 10}) async => const [];

  @override
  Future<Map<int, int>> getOrderCountsForInvoices(List<int> invoiceIds) async =>
      const {};
}
