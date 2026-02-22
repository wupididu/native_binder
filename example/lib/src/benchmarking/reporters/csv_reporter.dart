import '../benchmark_result.dart';

/// Exports benchmark results to CSV format
class CsvReporter {
  /// Convert a benchmark report to CSV string with full statistical data
  static String export(BenchmarkReport report, {bool includeRawData = false}) {
    final buffer = StringBuffer();

    // Metadata section
    buffer.writeln('# NativeBinder Performance Benchmark Results');
    buffer.writeln('# Timestamp: ${report.timestamp.toIso8601String()}');
    buffer.writeln('# Iterations: ${report.iterations}');
    buffer.writeln('# Platform: ${report.deviceInfo.platform}');
    buffer.writeln('# OS Version: ${report.deviceInfo.osVersion}');
    buffer.writeln('# Device: ${report.deviceInfo.deviceModel}');
    buffer.writeln('# Flutter Version: ${report.deviceInfo.flutterVersion}');
    buffer.writeln('# Dart Version: ${report.deviceInfo.dartVersion}');
    buffer.writeln('# Average Speedup: ${report.avgSpeedup.toStringAsFixed(2)}x');
    buffer.writeln('# Max Speedup: ${report.maxSpeedup.toStringAsFixed(2)}x (${report.maxSpeedupScenario})');
    buffer.writeln('#');

    // Header row
    buffer.writeln(_buildHeaderRow());

    // Data rows
    for (final result in report.results) {
      buffer.writeln(_buildDataRow(result));
    }

    return buffer.toString();
  }

  static String _buildHeaderRow() {
    return [
      'Scenario',
      'Description',
      'Direction',
      'Iterations',
      // Total metrics - grouped by type
      'NB_Total_Mean',
      'MC_Total_Mean',
      'NB_Total_Min',
      'MC_Total_Min',
      'NB_Total_Max',
      'MC_Total_Max',
      'NB_Total_StdDev',
      'MC_Total_StdDev',
      'NB_Total_P50',
      'MC_Total_P50',
      'NB_Total_P95',
      'MC_Total_P95',
      'NB_Total_P99',
      'MC_Total_P99',
      'NB_Total_CV',
      'MC_Total_CV',
      // NativeBinder Breakdown
      'NB_Encode_Mean',
      'NB_Encode_StdDev',
      'NB_Encode_P95',
      'NB_Native_Mean',
      'NB_Native_StdDev',
      'NB_Native_P95',
      'NB_Decode_Mean',
      'NB_Decode_StdDev',
      'NB_Decode_P95',
      // Native Breakdown (if available)
      'NB_NativeDecode_Mean',
      'NB_NativeHandler_Mean',
      'NB_NativeEncode_Mean',
      // Speedup
      'Speedup',
    ].join(',');
  }

  static String _buildDataRow(BenchmarkResult result) {
    return [
      _escape(result.name),
      _escape(result.description),
      result.direction.name,
      result.iterations.toString(),
      // Total metrics - grouped by type
      result.nativeBinderTotal.mean.toStringAsFixed(2),
      result.methodChannelTotal.mean.toStringAsFixed(2),
      result.nativeBinderTotal.min.toStringAsFixed(2),
      result.methodChannelTotal.min.toStringAsFixed(2),
      result.nativeBinderTotal.max.toStringAsFixed(2),
      result.methodChannelTotal.max.toStringAsFixed(2),
      result.nativeBinderTotal.stdDev.toStringAsFixed(2),
      result.methodChannelTotal.stdDev.toStringAsFixed(2),
      result.nativeBinderTotal.p50.toStringAsFixed(2),
      result.methodChannelTotal.p50.toStringAsFixed(2),
      result.nativeBinderTotal.p95.toStringAsFixed(2),
      result.methodChannelTotal.p95.toStringAsFixed(2),
      result.nativeBinderTotal.p99.toStringAsFixed(2),
      result.methodChannelTotal.p99.toStringAsFixed(2),
      result.nativeBinderTotal.coefficientOfVariation.toStringAsFixed(4),
      result.methodChannelTotal.coefficientOfVariation.toStringAsFixed(4),
      // NativeBinder Breakdown
      result.nativeBinderBreakdown.encode.mean.toStringAsFixed(2),
      result.nativeBinderBreakdown.encode.stdDev.toStringAsFixed(2),
      result.nativeBinderBreakdown.encode.p95.toStringAsFixed(2),
      result.nativeBinderBreakdown.native.mean.toStringAsFixed(2),
      result.nativeBinderBreakdown.native.stdDev.toStringAsFixed(2),
      result.nativeBinderBreakdown.native.p95.toStringAsFixed(2),
      result.nativeBinderBreakdown.decode.mean.toStringAsFixed(2),
      result.nativeBinderBreakdown.decode.stdDev.toStringAsFixed(2),
      result.nativeBinderBreakdown.decode.p95.toStringAsFixed(2),
      // Native Breakdown
      result.nativeBinderBreakdown.nativeDecode?.mean.toStringAsFixed(2) ?? '',
      result.nativeBinderBreakdown.nativeHandler?.mean.toStringAsFixed(2) ?? '',
      result.nativeBinderBreakdown.nativeEncode?.mean.toStringAsFixed(2) ?? '',
      // Speedup
      result.speedup.toStringAsFixed(2),
    ].join(',');
  }

  static String _escape(String value) {
    // Escape quotes and wrap in quotes if contains comma, newline, or quote
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
