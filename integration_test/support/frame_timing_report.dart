import 'dart:convert';
import 'dart:ffi' show Abi;

const ledgerBuildP90TargetMs = 8.0;
const ledgerRasterP90TargetMs = 8.0;
const ledgerBuildP99TargetMs = 16.0;
const ledgerRasterP99TargetMs = 16.0;
const ledgerSlowFrameTargetRatio = 0.01;
const ledgerMinimumMeasuredFrames = 120;
const _slowFrameThresholdMicroseconds =
    16 * Duration.microsecondsPerMillisecond;

class LedgerFrameSample {
  const LedgerFrameSample({
    required this.action,
    required this.buildMicroseconds,
    required this.rasterMicroseconds,
  });

  final String action;
  final int buildMicroseconds;
  final int rasterMicroseconds;
}

class LedgerProfileEnvironment {
  const LedgerProfileEnvironment({
    required this.profileMode,
    required this.isPhysicalDevice,
    required this.processAbi,
    required this.supportedAbis,
  });

  final bool profileMode;
  final bool isPhysicalDevice;
  final Abi processAbi;
  final List<String> supportedAbis;

  bool get isArm64Process => processAbi == Abi.androidArm64;

  bool get isRealArm64Device => isPhysicalDevice && isArm64Process;

  bool get canCertify => profileMode && isRealArm64Device;

  Map<String, Object> toJson() => {
    'profileMode': profileMode,
    'isPhysicalDevice': isPhysicalDevice,
    'processAbi': processAbi.toString(),
    'supportedAbis': supportedAbis,
    'realArm64Device': isRealArm64Device,
  };
}

class LedgerFrameTimingReport {
  LedgerFrameTimingReport._({
    required this.frameCount,
    required this.buildP90Ms,
    required this.buildP99Ms,
    required this.rasterP90Ms,
    required this.rasterP99Ms,
    required this.slowFrameCount,
    required this.slowFrameRatio,
    required this.framesByAction,
  });

  factory LedgerFrameTimingReport.fromSamples(List<LedgerFrameSample> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', '不得为空');
    }

    final builds = samples
        .map((sample) => sample.buildMicroseconds)
        .toList(growable: false);
    final rasters = samples
        .map((sample) => sample.rasterMicroseconds)
        .toList(growable: false);
    final slowFrameCount = samples
        .where(
          (sample) =>
              sample.buildMicroseconds > _slowFrameThresholdMicroseconds ||
              sample.rasterMicroseconds > _slowFrameThresholdMicroseconds,
        )
        .length;
    final framesByAction = <String, int>{};
    for (final sample in samples) {
      framesByAction.update(
        sample.action,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return LedgerFrameTimingReport._(
      frameCount: samples.length,
      buildP90Ms:
          _percentile(builds, 0.90) / Duration.microsecondsPerMillisecond,
      buildP99Ms:
          _percentile(builds, 0.99) / Duration.microsecondsPerMillisecond,
      rasterP90Ms:
          _percentile(rasters, 0.90) / Duration.microsecondsPerMillisecond,
      rasterP99Ms:
          _percentile(rasters, 0.99) / Duration.microsecondsPerMillisecond,
      slowFrameCount: slowFrameCount,
      slowFrameRatio: slowFrameCount / samples.length,
      framesByAction: Map.unmodifiable(framesByAction),
    );
  }

  final int frameCount;
  final double buildP90Ms;
  final double buildP99Ms;
  final double rasterP90Ms;
  final double rasterP99Ms;
  final int slowFrameCount;
  final double slowFrameRatio;
  final Map<String, int> framesByAction;

  bool get meetsTargets =>
      frameCount >= ledgerMinimumMeasuredFrames &&
      buildP90Ms <= ledgerBuildP90TargetMs &&
      buildP99Ms <= ledgerBuildP99TargetMs &&
      rasterP90Ms <= ledgerRasterP90TargetMs &&
      rasterP99Ms <= ledgerRasterP99TargetMs &&
      slowFrameRatio < ledgerSlowFrameTargetRatio;

  Map<String, Object> toJson({required LedgerProfileEnvironment environment}) =>
      {
        ...environment.toJson(),
        'certified': environment.canCertify && meetsTargets,
        'targetsPassed': meetsTargets,
        'frameCount': frameCount,
        'buildP90Ms': _round(buildP90Ms),
        'buildP99Ms': _round(buildP99Ms),
        'rasterP90Ms': _round(rasterP90Ms),
        'rasterP99Ms': _round(rasterP99Ms),
        'slowFrameCount': slowFrameCount,
        'slowFrameRatio': _round(slowFrameRatio),
        'framesByAction': framesByAction,
        'targets': const {
          'minimumMeasuredFrames': ledgerMinimumMeasuredFrames,
          'buildP90Ms': ledgerBuildP90TargetMs,
          'buildP99Ms': ledgerBuildP99TargetMs,
          'rasterP90Ms': ledgerRasterP90TargetMs,
          'rasterP99Ms': ledgerRasterP99TargetMs,
          'slowFrameRatioExclusiveMax': ledgerSlowFrameTargetRatio,
        },
      };

  String toJsonLine({required LedgerProfileEnvironment environment}) =>
      jsonEncode(toJson(environment: environment));
}

int _percentile(List<int> source, double percentile) {
  final sorted = [...source]..sort();
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index.clamp(0, sorted.length - 1)];
}

double _round(double value) => double.parse(value.toStringAsFixed(4));
