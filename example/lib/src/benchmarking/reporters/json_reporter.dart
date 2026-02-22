import 'dart:convert';
import '../benchmark_result.dart';

/// Exports benchmark results to JSON format
class JsonReporter {
  /// Convert a benchmark report to formatted JSON string
  static String export(BenchmarkReport report, {bool pretty = true}) {
    final json = report.toJson();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(json);
    }
    return jsonEncode(json);
  }

  /// Parse JSON string back to BenchmarkReport
  static BenchmarkReport parse(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);

    final results = (json['results'] as List)
        .map((r) => _parseResult(r as Map<String, dynamic>))
        .toList();

    return BenchmarkReport(
      results: results,
      timestamp: DateTime.parse(json['timestamp'] as String),
      iterations: json['iterations'] as int,
      deviceInfo: _parseDeviceInfo(json['deviceInfo'] as Map<String, dynamic>),
      avgSpeedup: (json['avgSpeedup'] as num).toDouble(),
      maxSpeedup: (json['maxSpeedup'] as num).toDouble(),
      maxSpeedupScenario: json['maxSpeedupScenario'] as String,
    );
  }

  static BenchmarkResult _parseResult(Map<String, dynamic> json) {
    return BenchmarkResult(
      name: json['name'] as String,
      description: json['description'] as String,
      direction: BenchmarkDirection.values.firstWhere(
        (d) => d.name == json['direction'],
      ),
      iterations: json['iterations'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      nativeBinderTotal: _parseStats(json['nativeBinderTotal'] as Map<String, dynamic>),
      methodChannelTotal: _parseStats(json['methodChannelTotal'] as Map<String, dynamic>),
      nativeBinderBreakdown: _parseBreakdown(json['nativeBinderBreakdown'] as Map<String, dynamic>),
      speedup: (json['speedup'] as num).toDouble(),
    );
  }

  static TimingStatistics _parseStats(Map<String, dynamic> json) {
    return TimingStatistics(
      mean: (json['mean'] as num).toDouble(),
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      stdDev: (json['stdDev'] as num).toDouble(),
      p50: (json['p50'] as num).toDouble(),
      p95: (json['p95'] as num).toDouble(),
      p99: (json['p99'] as num).toDouble(),
      coefficientOfVariation: (json['coefficientOfVariation'] as num).toDouble(),
      rawValues: const [],
    );
  }

  static NativeBinderTiming _parseBreakdown(Map<String, dynamic> json) {
    return NativeBinderTiming(
      encode: _parseStats(json['encode'] as Map<String, dynamic>),
      native: _parseStats(json['native'] as Map<String, dynamic>),
      decode: _parseStats(json['decode'] as Map<String, dynamic>),
      nativeDecode: json['nativeDecode'] != null
          ? _parseStats(json['nativeDecode'] as Map<String, dynamic>)
          : null,
      nativeHandler: json['nativeHandler'] != null
          ? _parseStats(json['nativeHandler'] as Map<String, dynamic>)
          : null,
      nativeEncode: json['nativeEncode'] != null
          ? _parseStats(json['nativeEncode'] as Map<String, dynamic>)
          : null,
    );
  }

  static DeviceInfo _parseDeviceInfo(Map<String, dynamic> json) {
    return DeviceInfo(
      platform: json['platform'] as String,
      osVersion: json['osVersion'] as String,
      deviceModel: json['deviceModel'] as String,
      flutterVersion: json['flutterVersion'] as String,
      dartVersion: json['dartVersion'] as String,
    );
  }
}
