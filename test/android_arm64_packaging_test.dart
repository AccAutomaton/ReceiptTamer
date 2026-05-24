import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android packaging warns for x64 runs and keeps arm64-only MNN defaults',
    () {
      final gradleProperties = File(
        'android/gradle.properties',
      ).readAsStringSync();
      final buildGradle = File(
        'android/app/build.gradle.kts',
      ).readAsStringSync();

      expect(gradleProperties, contains('target-platform=android-arm64'));
      expect(gradleProperties, contains('mnn.arm64Only=true'));
      expect(buildGradle, contains('"lib/x86_64/**"'));
      expect(buildGradle, contains('"lib/armeabi-v7a/**"'));
      expect(buildGradle, contains('mnnArm64Only'));
      expect(buildGradle, contains('ReceiptTamer MNN LLM Run Warning'));
      expect(buildGradle, contains('System.err.println(mnnFlutterRunWarning)'));
      expect(buildGradle, isNot(contains('throw GradleException')));
      expect(
        buildGradle,
        contains('ReceiptTamer local LLM requires an arm64 Flutter engine'),
      );
      expect(buildGradle, contains('android-x64'));
      expect(
        buildGradle,
        contains('flutter build apk --debug --target-platform android-arm64'),
      );
      expect(buildGradle, contains('adb install -r'));
      expect(buildGradle, contains('adb shell am start -n'));
      expect(buildGradle, contains('flutter attach'));
      expect(
        buildGradle,
        contains('flutter run does not support --target-platform'),
      );
    },
  );
}
