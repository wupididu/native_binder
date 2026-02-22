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
  final double p10;
  final double p25;
  final double p50; // Median
  final double p75;
  final double p90;
  final double p95;
  final double p99;
  final double p99_9;
  final double coefficientOfVariation;
  final double skewness;
  final double kurtosis;
  final double interquartileRange;
  final int outlierCount;
  final List<double> rawValues;

  const TimingStatistics({
    required this.mean,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
    required this.p95,
    required this.p99,
    required this.p99_9,
    required this.coefficientOfVariation,
    required this.skewness,
    required this.kurtosis,
    required this.interquartileRange,
    required this.outlierCount,
    required this.rawValues,
  });

  factory TimingStatistics.fromValues(List<double> values) {
    if (values.isEmpty) {
      return const TimingStatistics(
        mean: 0,
        min: 0,
        max: 0,
        stdDev: 0,
        p10: 0,
        p25: 0,
        p50: 0,
        p75: 0,
        p90: 0,
        p95: 0,
        p99: 0,
        p99_9: 0,
        coefficientOfVariation: 0,
        skewness: 0,
        kurtosis: 0,
        interquartileRange: 0,
        outlierCount: 0,
        rawValues: [],
      );
    }

    final sorted = List<double>.from(values)..sort();
    final n = values.length;
    final mean = values.reduce((a, b) => a + b) / n;
    final min = sorted.first;
    final max = sorted.last;

    // Calculate standard deviation
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / n;
    final stdDev = variance > 0 ? variance.sqrt() : 0.0;

    // Calculate percentiles
    final p10 = _percentile(sorted, 0.10);
    final p25 = _percentile(sorted, 0.25);
    final p50 = _percentile(sorted, 0.50);
    final p75 = _percentile(sorted, 0.75);
    final p90 = _percentile(sorted, 0.90);
    final p95 = _percentile(sorted, 0.95);
    final p99 = _percentile(sorted, 0.99);
    final p99_9 = _percentile(sorted, 0.999);

    // Coefficient of variation (relative standard deviation)
    final cv = mean > 0 ? (stdDev / mean) : 0.0;

    // Interquartile range
    final iqr = p75 - p25;

    // Calculate skewness: E[((X - mean) / stdDev)³]
    final skewness = stdDev > 0
        ? values.map((v) => ((v - mean) / stdDev).pow(3)).reduce((a, b) => a + b) / n
        : 0.0;

    // Calculate kurtosis (excess kurtosis): E[((X - mean) / stdDev)⁴] - 3
    final kurtosis = stdDev > 0
        ? (values.map((v) => ((v - mean) / stdDev).pow(4)).reduce((a, b) => a + b) / n) - 3
        : 0.0;

    // Count outliers (values beyond p75 + 1.5 * IQR or below p25 - 1.5 * IQR)
    final lowerBound = p25 - 1.5 * iqr;
    final upperBound = p75 + 1.5 * iqr;
    final outlierCount = values.where((v) => v < lowerBound || v > upperBound).length;

    return TimingStatistics(
      mean: mean,
      min: min,
      max: max,
      stdDev: stdDev,
      p10: p10,
      p25: p25,
      p50: p50,
      p75: p75,
      p90: p90,
      p95: p95,
      p99: p99,
      p99_9: p99_9,
      coefficientOfVariation: cv,
      skewness: skewness,
      kurtosis: kurtosis,
      interquartileRange: iqr,
      outlierCount: outlierCount,
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

  /// Get a percentile value at any percentile (0.0 to 1.0)
  double getPercentileValue(double percentile) {
    if (rawValues.isEmpty) return 0;
    final sorted = List<double>.from(rawValues)..sort();
    return _percentile(sorted, percentile);
  }

  /// Get interpretation of skewness
  String get skewnessInterpretation {
    if (skewness.abs() < 0.5) return 'Symmetric';
    if (skewness > 0) return 'Right-skewed (tail extends right)';
    return 'Left-skewed (tail extends left)';
  }

  /// Get consistency rating based on coefficient of variation
  String get consistencyRating {
    if (coefficientOfVariation < 0.1) return 'Excellent consistency';
    if (coefficientOfVariation < 0.25) return 'Good consistency';
    if (coefficientOfVariation < 0.5) return 'Moderate consistency';
    return 'High variance';
  }

  Map<String, dynamic> toJson() => {
        'mean': mean,
        'min': min,
        'max': max,
        'stdDev': stdDev,
        'p10': p10,
        'p25': p25,
        'p50': p50,
        'p75': p75,
        'p90': p90,
        'p95': p95,
        'p99': p99,
        'p99_9': p99_9,
        'coefficientOfVariation': coefficientOfVariation,
        'skewness': skewness,
        'kurtosis': kurtosis,
        'interquartileRange': interquartileRange,
        'outlierCount': outlierCount,
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

  double pow(int exponent) {
    if (exponent == 0) return 1.0;
    if (exponent == 1) return this;
    double result = 1.0;
    double base = this;
    int exp = exponent.abs();

    while (exp > 0) {
      if (exp % 2 == 1) {
        result *= base;
      }
      base *= base;
      exp ~/= 2;
    }

    return exponent < 0 ? 1.0 / result : result;
  }
}
