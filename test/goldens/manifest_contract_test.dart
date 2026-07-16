import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('31 个 Android 截图场景与验收矩阵保持完整', () {
    final manifest =
        jsonDecode(
              File('test/goldens/scenarios/manifest.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final scenarios = manifest['scenarios'] as List<dynamic>;
    final matrix = manifest['matrix'] as Map<String, dynamic>;

    expect(manifest['schemaVersion'], 3);
    expect(
      (manifest['contentBaseline'] as Map<String, dynamic>)['id'],
      'reimbursement_binding_approved',
    );
    expect(scenarios, hasLength(31));
    expect(
      scenarios.map((item) => (item as Map<String, dynamic>)['id']).toSet(),
      hasLength(31),
    );
    expect(
      scenarios.every(
        (item) =>
            (item as Map<String, dynamic>)['states'] is List<dynamic> &&
            (item['states'] as List<dynamic>).isNotEmpty,
      ),
      isTrue,
    );
    expect(matrix['viewports'], [
      {'id': 'android_regular', 'width': 412, 'height': 915},
      {'id': 'android_compact', 'width': 360, 'height': 800},
    ]);
    expect(matrix['themes'], ['light', 'dark']);
    expect(matrix['textScales'], [1.0, 1.3, 2.0]);

    final locations = scenarios
        .map((item) => (item as Map<String, dynamic>)['location'] as String)
        .toSet();
    expect(
      locations,
      containsAll(<String>{
        '/',
        '/orders',
        '/invoices',
        '/settings',
        '/orders/new',
        '/invoices/new?orderIds=101,102',
        '/export',
        '/export/check',
        '/invoice-assistant',
        '/settings/cleanup',
        'dialog://saved-files',
        'sheet://receipt-intake',
      }),
    );

    final routePatterns = scenarios
        .map((item) => item as Map<String, dynamic>)
        .where((item) => item['kind'] == 'route')
        .map(
          (item) =>
              item['routePattern'] as String? ??
              Uri.parse(item['location'] as String).path,
        )
        .toSet();
    expect(routePatterns, {
      '/',
      '/orders',
      '/invoices',
      '/settings',
      '/orders/new',
      '/orders/select',
      '/invoices/select',
      '/orders/:id',
      '/orders/:id/edit',
      '/invoices/new',
      '/invoices/:id',
      '/invoices/:id/edit',
      '/export',
      '/export/check',
      '/export/invoices',
      '/export/orders',
      '/export/options',
      '/export/meal-proof',
      '/export/invoice',
      '/invoice-assistant',
      '/settings/model-management',
      '/settings/storage',
      '/settings/privacy',
      '/settings/open-source',
      '/settings/release-history',
      '/settings/cleanup',
      '/settings/cleanup/orders',
      '/settings/cleanup/invoices',
      '/share',
    });
  });
}
