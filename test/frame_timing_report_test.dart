import 'dart:ffi' show Abi;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/frame_timing_report.dart';

void main() {
  final passingReport = LedgerFrameTimingReport.fromSamples(
    List.generate(
      ledgerMinimumMeasuredFrames,
      (index) => LedgerFrameSample(
        action: index.isEven ? 'orders-scroll' : 'month-jump',
        buildMicroseconds: 1000,
        rasterMicroseconds: 1000,
      ),
    ),
  );

  test('认证只接受 profile 模式下的物理 Android ARM64 进程', () {
    const environment = LedgerProfileEnvironment(
      profileMode: true,
      isPhysicalDevice: true,
      processAbi: Abi.androidArm64,
      supportedAbis: ['arm64-v8a'],
    );

    final json = passingReport.toJson(environment: environment);

    expect(json['profileMode'], isTrue);
    expect(json['realArm64Device'], isTrue);
    expect(json['certified'], isTrue);
  });

  test('ARM64 模拟器不能认证', () {
    const environment = LedgerProfileEnvironment(
      profileMode: true,
      isPhysicalDevice: false,
      processAbi: Abi.androidArm64,
      supportedAbis: ['arm64-v8a'],
    );

    final json = passingReport.toJson(environment: environment);

    expect(json['realArm64Device'], isFalse);
    expect(json['certified'], isFalse);
  });

  test('supported ABI 不能替代实际进程 ABI', () {
    const environment = LedgerProfileEnvironment(
      profileMode: true,
      isPhysicalDevice: true,
      processAbi: Abi.androidX64,
      supportedAbis: ['x86_64', 'arm64-v8a'],
    );

    final json = passingReport.toJson(environment: environment);

    expect(json['realArm64Device'], isFalse);
    expect(json['certified'], isFalse);
  });

  test('非 profile 构建不能认证', () {
    const environment = LedgerProfileEnvironment(
      profileMode: false,
      isPhysicalDevice: true,
      processAbi: Abi.androidArm64,
      supportedAbis: ['arm64-v8a'],
    );

    final json = passingReport.toJson(environment: environment);

    expect(json['realArm64Device'], isTrue);
    expect(json['certified'], isFalse);
  });
}
