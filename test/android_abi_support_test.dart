import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android MNN support checks installed native ABI, not only device ABI list',
    () {
      final source = File(
        'android/app/src/main/kotlin/com/acautomaton/receipt/tamer/MainActivity.kt',
      ).readAsStringSync();

      expect(source, contains('applicationInfo.nativeLibraryDir'));
      expect(source, contains('getInstalledNativeAbi()'));
      expect(source, contains('isCurrentProcessArm64V8()'));
      expect(source, isNot(contains('getDeviceArch() == "arm64-v8a"')));
      expect(source, isNot(contains('arch != "arm64-v8a"')));
      expect(
        source,
        isNot(contains('Build.SUPPORTED_ABIS.contains("arm64-v8a")')),
      );
    },
  );
}
