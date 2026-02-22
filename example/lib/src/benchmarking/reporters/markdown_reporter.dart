import '../benchmark_result.dart';

/// Exports benchmark results to Markdown format
class MarkdownReporter {
  /// Convert a benchmark report to formatted Markdown
  static String export(BenchmarkReport report, {bool includeDetailedStats = false}) {
    final buffer = StringBuffer();

    // Title and metadata
    buffer.writeln('# NativeBinder Performance Benchmark Results');
    buffer.writeln();
    buffer.writeln('## Test Configuration');
    buffer.writeln();
    buffer.writeln('| Property | Value |');
    buffer.writeln('|----------|-------|');
    buffer.writeln('| **Date** | ${_formatTimestamp(report.timestamp)} |');
    buffer.writeln('| **Iterations** | ${report.iterations} |');
    buffer.writeln('| **Platform** | ${report.deviceInfo.platform.toUpperCase()} |');
    buffer.writeln('| **OS Version** | ${report.deviceInfo.osVersion} |');
    buffer.writeln('| **Device** | ${report.deviceInfo.deviceModel} |');
    buffer.writeln('| **Flutter Version** | ${report.deviceInfo.flutterVersion} |');
    buffer.writeln('| **Dart Version** | ${report.deviceInfo.dartVersion} |');
    buffer.writeln();

    // Summary statistics
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('- **Average Speedup:** ${report.avgSpeedup.toStringAsFixed(1)}x faster than MethodChannel');
    buffer.writeln('- **Maximum Speedup:** ${report.maxSpeedup.toStringAsFixed(1)}x (${report.maxSpeedupScenario})');
    buffer.writeln();

    // Results table
    buffer.writeln('## Benchmark Results');
    buffer.writeln();
    buffer.writeln('All times in microseconds (µs).');
    buffer.writeln();

    if (includeDetailedStats) {
      buffer.writeln(_buildDetailedTable(report.results));
    } else {
      buffer.writeln(_buildSummaryTable(report.results));
    }

    // Interpretation guide
    buffer.writeln();
    buffer.writeln('## Interpretation');
    buffer.writeln();
    buffer.writeln('- **Encode**: Time spent encoding arguments in Dart using StandardMessageCodec');
    buffer.writeln('- **Native**: Time spent in FFI call + native execution (decode + handler + encode)');
    buffer.writeln('- **Decode**: Time spent decoding response in Dart');
    buffer.writeln('- **NB Total**: Total NativeBinder execution time (synchronous)');
    buffer.writeln('- **MC Total**: Total MethodChannel execution time (async)');
    buffer.writeln('- **Speedup**: Ratio of MethodChannel time to NativeBinder time');
    buffer.writeln();

    return buffer.toString();
  }

  static String _buildSummaryTable(List<BenchmarkResult> results) {
    final buffer = StringBuffer();

    buffer.writeln('| Scenario | Encode | Native | Decode | NB Total | MC Total | Speedup |');
    buffer.writeln('|----------|--------|--------|--------|----------|----------|---------|');

    for (final result in results) {
      buffer.writeln([
        '| ${result.name}',
        _formatMicros(result.nativeBinderBreakdown.encode.mean),
        _formatMicros(result.nativeBinderBreakdown.native.mean),
        _formatMicros(result.nativeBinderBreakdown.decode.mean),
        _formatMicros(result.nativeBinderTotal.mean),
        _formatMicros(result.methodChannelTotal.mean),
        '**${result.speedup.toStringAsFixed(1)}x** |',
      ].join(' | '));
    }

    return buffer.toString();
  }

  static String _buildDetailedTable(List<BenchmarkResult> results) {
    final buffer = StringBuffer();

    buffer.writeln('| Scenario | NB Mean±SD | MC Mean±SD | NB P95/P99 | MC P95/P99 | Speedup |');
    buffer.writeln('|----------|------------|------------|------------|------------|---------|');

    for (final result in results) {
      final nbStats = result.nativeBinderTotal;
      final mcStats = result.methodChannelTotal;

      buffer.writeln([
        '| ${result.name}',
        '${_formatMicros(nbStats.mean)}±${_formatMicros(nbStats.stdDev)}',
        '${_formatMicros(mcStats.mean)}±${_formatMicros(mcStats.stdDev)}',
        '${_formatMicros(nbStats.p95)}/${_formatMicros(nbStats.p99)}',
        '${_formatMicros(mcStats.p95)}/${_formatMicros(mcStats.p99)}',
        '**${result.speedup.toStringAsFixed(1)}x** |',
      ].join(' | '));
    }

    buffer.writeln();
    buffer.writeln('### Percentile Distribution (NativeBinder)');
    buffer.writeln();
    buffer.writeln('All times in microseconds (µs).');
    buffer.writeln();
    buffer.writeln('| Scenario | P10 | P25 | P50 | P75 | P90 | P95 | P99 | P99.9 |');
    buffer.writeln('|----------|-----|-----|-----|-----|-----|-----|-----|-------|');

    for (final result in results) {
      final stats = result.nativeBinderTotal;
      buffer.writeln([
        '| ${result.name}',
        _formatMicros(stats.p10),
        _formatMicros(stats.p25),
        _formatMicros(stats.p50),
        _formatMicros(stats.p75),
        _formatMicros(stats.p90),
        _formatMicros(stats.p95),
        _formatMicros(stats.p99),
        '${_formatMicros(stats.p99_9)} |',
      ].join(' | '));
    }

    buffer.writeln();
    buffer.writeln('### Statistical Analysis');
    buffer.writeln();
    buffer.writeln('| Scenario | Consistency | Skewness | IQR (µs) | Outliers | Kurtosis |');
    buffer.writeln('|----------|-------------|----------|----------|----------|----------|');

    for (final result in results) {
      final stats = result.nativeBinderTotal;
      final outlierPercent = (stats.outlierCount / stats.rawValues.length * 100).toStringAsFixed(1);

      buffer.writeln([
        '| ${result.name}',
        stats.consistencyRating,
        stats.skewnessInterpretation,
        _formatMicros(stats.interquartileRange),
        '${stats.outlierCount} ($outlierPercent%)',
        '${stats.kurtosis.toStringAsFixed(2)} |',
      ].join(' | '));
    }

    buffer.writeln();
    buffer.writeln('### Timing Breakdown by Phase');
    buffer.writeln();
    buffer.writeln('| Scenario | Encode (µs) | Native (µs) | Decode (µs) | Total (µs) |');
    buffer.writeln('|----------|-------------|-------------|-------------|------------|');

    for (final result in results) {
      final breakdown = result.nativeBinderBreakdown;
      buffer.writeln([
        '| ${result.name}',
        _formatMicros(breakdown.encode.mean),
        _formatMicros(breakdown.native.mean),
        _formatMicros(breakdown.decode.mean),
        '${_formatMicros(result.nativeBinderTotal.mean)} |',
      ].join(' | '));
    }

    return buffer.toString();
  }

  static String _formatMicros(double micros) {
    if (micros < 10) {
      return micros.toStringAsFixed(2);
    } else if (micros < 100) {
      return micros.toStringAsFixed(1);
    } else {
      return micros.round().toString();
    }
  }

  static String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
