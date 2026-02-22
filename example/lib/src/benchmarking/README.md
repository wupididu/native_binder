# NativeBinder Benchmarking System

This directory contains a comprehensive benchmarking framework for analyzing the performance of native_binder compared to Flutter's MethodChannel.

## Architecture

The benchmarking system follows a modular architecture:

```
src/benchmarking/
├── benchmark_result.dart      # Data models (BenchmarkResult, TimingStatistics, etc.)
├── benchmark_runner.dart      # Core benchmark execution engine
├── scenarios.dart             # Pre-defined benchmark scenarios
├── reporters/                 # Export functionality
│   ├── csv_reporter.dart      # CSV export with full statistics
│   ├── json_reporter.dart     # JSON export for programmatic analysis
│   └── markdown_reporter.dart # Markdown reports for documentation
└── widgets/                   # UI components
    └── benchmark_charts.dart  # Interactive charts using fl_chart
```

## Key Features

### 1. Statistical Analysis

Beyond simple averages, the system provides comprehensive statistical metrics:

- **Mean**: Average timing across all iterations
- **Standard Deviation**: Measure of timing variability
- **Percentiles (P50, P95, P99)**: Understanding distribution and outliers
- **Coefficient of Variation**: Relative variability metric
- **Min/Max**: Extreme values for outlier detection

### 2. Detailed Timing Breakdown

Each benchmark captures granular timing for:

- **Encode (Dart)**: Time to encode arguments using StandardMessageCodec
- **Native (FFI+exec)**: Total native execution time including:
  - Native Decode: Decoding arguments on native side
  - Native Handler: Actual handler execution time
  - Native Encode: Encoding response on native side
- **Decode (Dart)**: Time to decode response in Dart

### 3. Multiple Export Formats

Results can be exported in three formats:

**CSV**: Full statistical data suitable for spreadsheet analysis
```dart
final csv = CsvReporter.export(report);
```

**JSON**: Structured data for programmatic processing
```dart
final json = JsonReporter.export(report, pretty: true);
```

**Markdown**: Formatted reports for README/documentation
```dart
final markdown = MarkdownReporter.export(report, includeDetailedStats: true);
```

### 4. Visual Charts

Interactive visualizations using fl_chart:

- **Timing Breakdown Chart**: Stacked bar chart showing encode/native/decode phases
- **Speedup Comparison Chart**: Bar chart comparing speedup factors across scenarios
- **Statistical Distribution Chart**: Box plot showing timing distribution

### 5. Scenario Management

Pre-defined scenarios organized by category:

- **Basic**: Primitives and simple strings
- **Collections**: Lists and maps of varying sizes
- **Complex**: Nested structures and mixed types
- **Error**: Error handling performance (planned)
- **Native→Dart**: Reverse direction calls (planned)
- **Concurrent**: Simultaneous call performance (planned)

## Usage

### In UI

```dart
import 'package:native_binder_example/src/benchmarking/benchmark_runner.dart';

final runner = BenchmarkRunner(
  channelName: 'example_channel',
  methodChannelName: 'native_binder_perf',
);

final report = await runner.runAll(
  iterations: 500,
  onProgress: (scenarioName, completed, total) {
    print('Running $scenarioName ($completed/$total)');
  },
);

// Access results
print('Average speedup: ${report.avgSpeedup}x');
for (final result in report.results) {
  print('${result.name}: ${result.speedup}x');
}
```

### Programmatic Export

```dart
import 'package:native_binder_example/src/benchmarking/reporters/json_reporter.dart';

// Export to JSON
final jsonString = JsonReporter.export(report);
await File('results.json').writeAsString(jsonString);

// Later, parse back
final loadedReport = JsonReporter.parse(jsonString);
```

### Custom Scenarios

```dart
import 'package:native_binder_example/src/benchmarking/benchmark_result.dart';

final customScenario = BenchmarkScenario(
  name: 'My Custom Test',
  description: 'Tests custom payload',
  nativeMethod: 'myMethod',
  channelMethod: 'myMethod',
  payloadBuilder: () => {'custom': 'data'},
  direction: BenchmarkDirection.dartToNative,
);

final runner = BenchmarkRunner(
  channelName: 'example_channel',
  methodChannelName: 'native_binder_perf',
  scenarios: [customScenario],
);
```

## Data Models

### BenchmarkResult

Represents the complete result of a single benchmark scenario:

```dart
class BenchmarkResult {
  final String name;
  final String description;
  final int iterations;
  final TimingStatistics nativeBinderTotal;
  final TimingStatistics methodChannelTotal;
  final NativeBinderTiming nativeBinderBreakdown;
  final double speedup;
  final DateTime timestamp;
}
```

### TimingStatistics

Statistical analysis of timing measurements:

```dart
class TimingStatistics {
  final double mean;
  final double min;
  final double max;
  final double stdDev;
  final double p50;  // Median
  final double p95;
  final double p99;
  final double coefficientOfVariation;
}
```

### BenchmarkReport

Complete benchmark run with all scenarios:

```dart
class BenchmarkReport {
  final List<BenchmarkResult> results;
  final DateTime timestamp;
  final int iterations;
  final DeviceInfo deviceInfo;
  final double avgSpeedup;
  final double maxSpeedup;
  final String maxSpeedupScenario;
}
```

## CI/CD Integration

The benchmarking system supports automated testing via the CLI tool:

```bash
# Run benchmarks
dart run tool/benchmark_cli.dart --iterations 1000 --output results.json

# Compare with baseline
dart run tool/benchmark_cli.dart \
  --baseline baseline.json \
  --threshold 10 \
  --output current.json
```

See `.github/workflows/performance.yml` for GitHub Actions integration example.

## Best Practices

1. **Warm-up**: The runner automatically performs 20 warm-up iterations before measurement
2. **Iteration count**: Use at least 500 iterations for stable statistics (1000+ recommended for CI)
3. **Device variation**: Results vary by device - always test on target hardware
4. **Baseline tracking**: Establish baselines on representative devices for regression detection
5. **Statistical interpretation**: Focus on P95/P99 for worst-case performance analysis

## Extending the System

To add new test scenarios:

1. Add scenario definition to `scenarios.dart`
2. Implement corresponding native handlers if needed
3. Scenarios are automatically picked up by the runner

To add new export formats:

1. Create new reporter in `reporters/` directory
2. Implement export logic using `BenchmarkReport` data
3. Add to export menu in UI

To add new chart types:

1. Create widget in `widgets/benchmark_charts.dart`
2. Use `fl_chart` library for visualization
3. Add to charts view in performance screen
