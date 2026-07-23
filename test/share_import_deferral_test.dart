import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_tamer/data/services/share_handler_service.dart';
import 'package:receipt_tamer/presentation/screens/share/share_target_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  final service = ShareHandlerService();

  tearDown(() {
    service.clearPendingSharedMedia();
  });

  testWidgets('later preserves pending share items and exposes a resume path', (
    tester,
  ) async {
    final items = [
      const SharedMediaItem(
        path: 'missing-order-image.jpg',
        type: SharedMediaType.image,
      ),
    ];
    service.sharedMediaNotifier.value = items;
    final router = _router(items);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('稍后处理'));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(service.pendingSharedMedia, same(items));
  });

  testWidgets('abandon all requires confirmation before clearing the queue', (
    tester,
  ) async {
    final items = [
      const SharedMediaItem(
        path: 'missing-invoice.pdf',
        type: SharedMediaType.file,
      ),
    ];
    service.sharedMediaNotifier.value = items;
    final router = _router(items);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃全部'));
    await tester.pumpAndSettle();

    expect(find.text('放弃全部待处理文件？'), findsOneWidget);
    expect(service.pendingSharedMedia, same(items));

    await tester.tap(find.text('放弃全部').last);
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(service.pendingSharedMedia, isNull);
  });

  testWidgets('opening an editor keeps the current shared file pending', (
    tester,
  ) async {
    final items = [
      const SharedMediaItem(
        path: 'order-image.jpg',
        type: SharedMediaType.image,
      ),
      const SharedMediaItem(path: 'invoice.pdf', type: SharedMediaType.file),
    ];
    service.sharedMediaNotifier.value = items;
    final router = _router(items);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加为订单 (1 个图片)'));
    await tester.pumpAndSettle();

    expect(service.pendingSharedMedia, orderedEquals(items));
  });

  test(
    'new shares merge with a deferred queue and completed items leave it',
    () {
      const first = SharedMediaItem(
        path: 'first.jpg',
        type: SharedMediaType.image,
      );
      const second = SharedMediaItem(
        path: 'second.pdf',
        type: SharedMediaType.file,
      );
      service.sharedMediaNotifier.value = [first];

      service.enqueueSharedMedia([first, second]);
      expect(service.pendingSharedMedia, orderedEquals([first, second]));

      service.completePendingSharedMedia(first.path);
      expect(service.pendingSharedMedia, orderedEquals([second]));
    },
  );
}

GoRouter _router(List<SharedMediaItem> items) {
  return GoRouter(
    initialLocation: '/share',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('首页'))),
      ),
      GoRoute(
        path: '/share',
        builder: (context, state) => ShareTargetScreen(sharedItems: items),
      ),
      GoRoute(
        path: '/orders/new',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/invoices/new',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}
