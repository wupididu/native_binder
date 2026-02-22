import 'package:flutter/services.dart';
import 'package:native_binder/native_binder.dart';
import 'benchmark_result.dart';
import 'scenarios.dart';

/// Callback for progress updates during benchmark execution
typedef ProgressCallback = void Function(String scenarioName, int completed, int total);

/// Orchestrates benchmark execution and data collection
class BenchmarkRunner {
  final NativeBinder _nativeBinder;
  final MethodChannel _methodChannel;
  final List<BenchmarkScenario> scenarios;
  final int warmupIterations;

  BenchmarkRunner({
    required String channelName,
    required String methodChannelName,
    List<BenchmarkScenario>? scenarios,
    this.warmupIterations = 20,
  })  : _nativeBinder = NativeBinder(channelName),
        _methodChannel = MethodChannel(methodChannelName),
        scenarios = scenarios ?? BenchmarkScenarios.allScenarios;

  /// Run all benchmarks and return a complete report
  Future<BenchmarkReport> runAll({
    required int iterations,
    ProgressCallback? onProgress,
  }) async {
    if (!NativeBinder.isSupported) {
      throw UnsupportedError('Native bindings not supported on this platform');
    }

    final results = <BenchmarkResult>[];
    final timestamp = DateTime.now();

    for (int i = 0; i < scenarios.length; i++) {
      final scenario = scenarios[i];
      onProgress?.call(scenario.name, i, scenarios.length);

      final result = await _runScenario(
        scenario: scenario,
        iterations: iterations,
      );
      results.add(result);
    }

    // Calculate summary statistics
    final speedups = results.map((r) => r.speedup).toList();
    final avgSpeedup = speedups.reduce((a, b) => a + b) / speedups.length;
    final maxSpeedup = speedups.reduce((a, b) => a > b ? a : b);
    final maxScenario = results.firstWhere((r) => r.speedup == maxSpeedup).name;

    return BenchmarkReport(
      results: results,
      timestamp: timestamp,
      iterations: iterations,
      deviceInfo: DeviceInfo.current(),
      avgSpeedup: avgSpeedup,
      maxSpeedup: maxSpeedup,
      maxSpeedupScenario: maxScenario,
    );
  }

  /// Run a single benchmark scenario
  Future<BenchmarkResult> _runScenario({
    required BenchmarkScenario scenario,
    required int iterations,
  }) async {
    final payload = scenario.payloadBuilder();

    // Warm up phase
    for (int i = 0; i < warmupIterations; i++) {
      if (scenario.direction == BenchmarkDirection.dartToNative) {
        _nativeBinder.invokeMethod(scenario.nativeMethod, payload);
        await _methodChannel.invokeMethod(scenario.channelMethod, payload);
      } else {
        // For native→dart, warmup would need native-side triggering
        // Skip for now as warmup is less critical for reverse direction
      }
    }

    // Collect NativeBinder detailed timing data
    final nbTotalTimes = <double>[];
    final nbEncodeTimes = <double>[];
    final nbNativeTimes = <double>[];
    final nbDecodeTimes = <double>[];
    final nbNativeDecodeTimes = <double>[];
    final nbNativeHandlerTimes = <double>[];
    final nbNativeEncodeTimes = <double>[];

    for (int i = 0; i < iterations; i++) {
      if (scenario.direction == BenchmarkDirection.dartToNative) {
        final timing = _nativeBinder.invokeMethodWithTiming(
          scenario.nativeMethod,
          payload,
        );

        final total = timing.encodeTimeUs + timing.nativeTimeUs + timing.decodeTimeUs;
        nbTotalTimes.add(total);
        nbEncodeTimes.add(timing.encodeTimeUs);
        nbNativeTimes.add(timing.nativeTimeUs);
        nbDecodeTimes.add(timing.decodeTimeUs);

        if (timing.nativeDecodeTimeUs != null) {
          nbNativeDecodeTimes.add(timing.nativeDecodeTimeUs!);
          nbNativeHandlerTimes.add(timing.nativeHandlerTimeUs!);
          nbNativeEncodeTimes.add(timing.nativeEncodeTimeUs!);
        }
      } else {
        // Native→Dart benchmarking would require native-side implementation
        // For now, collect basic timing
        final start = DateTime.now().microsecondsSinceEpoch;
        _nativeBinder.invokeMethod(scenario.nativeMethod, payload);
        final end = DateTime.now().microsecondsSinceEpoch;
        nbTotalTimes.add((end - start).toDouble());
      }
    }

    // Collect MethodChannel timing data
    final mcTotalTimes = <double>[];
    for (int i = 0; i < iterations; i++) {
      final start = DateTime.now().microsecondsSinceEpoch;
      await _methodChannel.invokeMethod(scenario.channelMethod, payload);
      final end = DateTime.now().microsecondsSinceEpoch;
      mcTotalTimes.add((end - start).toDouble());
    }

    // Calculate statistics
    final nbTotalStats = TimingStatistics.fromValues(nbTotalTimes);
    final mcTotalStats = TimingStatistics.fromValues(mcTotalTimes);

    final nbBreakdown = NativeBinderTiming(
      encode: TimingStatistics.fromValues(nbEncodeTimes),
      native: TimingStatistics.fromValues(nbNativeTimes),
      decode: TimingStatistics.fromValues(nbDecodeTimes),
      nativeDecode: nbNativeDecodeTimes.isNotEmpty
          ? TimingStatistics.fromValues(nbNativeDecodeTimes)
          : null,
      nativeHandler: nbNativeHandlerTimes.isNotEmpty
          ? TimingStatistics.fromValues(nbNativeHandlerTimes)
          : null,
      nativeEncode: nbNativeEncodeTimes.isNotEmpty
          ? TimingStatistics.fromValues(nbNativeEncodeTimes)
          : null,
    );

    final speedup = nbTotalStats.mean > 0 ? mcTotalStats.mean / nbTotalStats.mean : double.infinity;

    return BenchmarkResult(
      name: scenario.name,
      description: scenario.description,
      direction: scenario.direction,
      iterations: iterations,
      nativeBinderTotal: nbTotalStats,
      methodChannelTotal: mcTotalStats,
      nativeBinderBreakdown: nbBreakdown,
      speedup: speedup,
      timestamp: DateTime.now(),
    );
  }
}
