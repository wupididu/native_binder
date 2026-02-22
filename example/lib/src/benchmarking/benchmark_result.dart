import 'dart:io';

/// Represents a single benchmark scenario configuration
class BenchmarkScenario {
  final String name;
  final String description;
  final String nativeMethod;
  final String channelMethod;
  final dynamic Function() payloadBuilder;
  final BenchmarkDirection direction;

  const BenchmarkScenario({
    required this.name,
    required this.description,
    required this.nativeMethod,
    required this.channelMethod,
    required this.payloadBuilder,
    this.direction = BenchmarkDirection.dartToNative,
  });
}

/// Direction of the benchmark call
enum BenchmarkDirection {
  dartToNative,
  nativeToDart,
}

/// Statistical metrics for a set of measurements
class TimingStatistics {
  final double mean;
  final double min;
  final double max;
  final double stdDev;
  final double p50; // Median
  final double p95;
  final double p99;
  final double coefficientOfVariation;
  final List<double> rawValues;

  const TimingStatistics({
    required this.mean,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.p50,
    required this.p95,
    required this.p99,
    required this.coefficientOfVariation,
    required this.rawValues,
  });

  factory TimingStatistics.fromValues(List<double> values) {
    if (values.isEmpty) {
      return const TimingStatistics(
        mean: 0,
        min: 0,
        max: 0,
        stdDev: 0,
        p50: 0,
        p95: 0,
        p99: 0,
        coefficientOfVariation: 0,
        rawValues: [],
      );
    }

    final sorted = List<double>.from(values)..sort();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final min = sorted.first;
    final max = sorted.last;

    // Calculate standard deviation
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    final stdDev = variance > 0 ? variance.sqrt() : 0.0;

    // Calculate percentiles
    final p50 = _percentile(sorted, 0.50);
    final p95 = _percentile(sorted, 0.95);
    final p99 = _percentile(sorted, 0.99);

    // Coefficient of variation (relative standard deviation)
    final cv = mean > 0 ? (stdDev / mean) : 0.0;

    return TimingStatistics(
      mean: mean,
      min: min,
      max: max,
      stdDev: stdDev,
      p50: p50,
      p95: p95,
      p99: p99,
      coefficientOfVariation: cv,
      rawValues: List.unmodifiable(values),
    );
  }

  static double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;
    final index = (sortedValues.length - 1) * percentile;
    final lower = index.floor();
    final upper = index.ceil();
    final weight = index - lower;
    return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
  }

  Map<String, dynamic> toJson() => {
        'mean': mean,
        'min': min,
        'max': max,
        'stdDev': stdDev,
        'p50': p50,
        'p95': p95,
        'p99': p99,
        'coefficientOfVariation': coefficientOfVariation,
      };
}

/// Detailed timing breakdown for NativeBinder calls
class NativeBinderTiming {
  final TimingStatistics encode;
  final TimingStatistics native;
  final TimingStatistics decode;
  final TimingStatistics? nativeDecode;
  final TimingStatistics? nativeHandler;
  final TimingStatistics? nativeEncode;

  const NativeBinderTiming({
    required this.encode,
    required this.native,
    required this.decode,
    this.nativeDecode,
    this.nativeHandler,
    this.nativeEncode,
  });

  Map<String, dynamic> toJson() => {
        'encode': encode.toJson(),
        'native': native.toJson(),
        'decode': decode.toJson(),
        if (nativeDecode != null) 'nativeDecode': nativeDecode!.toJson(),
        if (nativeHandler != null) 'nativeHandler': nativeHandler!.toJson(),
        if (nativeEncode != null) 'nativeEncode': nativeEncode!.toJson(),
      };
}

/// Complete benchmark result for a single scenario
class BenchmarkResult {
  final String name;
  final String description;
  final BenchmarkDirection direction;
  final int iterations;
  final TimingStatistics nativeBinderTotal;
  final TimingStatistics methodChannelTotal;
  final NativeBinderTiming nativeBinderBreakdown;
  final double speedup;
  final DateTime timestamp;

  const BenchmarkResult({
    required this.name,
    required this.description,
    required this.direction,
    required this.iterations,
    required this.nativeBinderTotal,
    required this.methodChannelTotal,
    required this.nativeBinderBreakdown,
    required this.speedup,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'direction': direction.name,
        'iterations': iterations,
        'timestamp': timestamp.toIso8601String(),
        'nativeBinderTotal': nativeBinderTotal.toJson(),
        'methodChannelTotal': methodChannelTotal.toJson(),
        'nativeBinderBreakdown': nativeBinderBreakdown.toJson(),
        'speedup': speedup,
      };
}

/// Complete benchmark run containing all scenario results
class BenchmarkReport {
  final List<BenchmarkResult> results;
  final DateTime timestamp;
  final int iterations;
  final DeviceInfo deviceInfo;
  final double avgSpeedup;
  final double maxSpeedup;
  final String maxSpeedupScenario;

  const BenchmarkReport({
    required this.results,
    required this.timestamp,
    required this.iterations,
    required this.deviceInfo,
    required this.avgSpeedup,
    required this.maxSpeedup,
    required this.maxSpeedupScenario,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'iterations': iterations,
        'deviceInfo': deviceInfo.toJson(),
        'avgSpeedup': avgSpeedup,
        'maxSpeedup': maxSpeedup,
        'maxSpeedupScenario': maxSpeedupScenario,
        'results': results.map((r) => r.toJson()).toList(),
      };
}

/// Device/platform information for benchmark context
class DeviceInfo {
  final String platform; // 'android' or 'ios'
  final String osVersion;
  final String deviceModel;
  final String flutterVersion;
  final String dartVersion;

  const DeviceInfo({
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.flutterVersion,
    required this.dartVersion,
  });

  static DeviceInfo current() {
    return DeviceInfo(
      platform: Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown',
      osVersion: Platform.operatingSystemVersion,
      deviceModel: 'Unknown', // Will be populated from native code
      flutterVersion: 'Unknown', // Could be injected
      dartVersion: Platform.version.split(' ').first,
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'osVersion': osVersion,
        'deviceModel': deviceModel,
        'flutterVersion': flutterVersion,
        'dartVersion': dartVersion,
      };
}

extension DoubleExtensions on double {
  double sqrt() {
    if (this < 0) return 0;
    double x = this;
    double y = (x + 1) / 2;
    while (y < x) {
      x = y;
      y = (x + this / x) / 2;
    }
    return x;
  }
}
