import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_binder/native_binder.dart';
import '../src/benchmarking/benchmark_result.dart';
import '../src/benchmarking/benchmark_runner.dart';
import '../src/benchmarking/reporters/csv_reporter.dart';
import '../src/benchmarking/reporters/json_reporter.dart';
import '../src/benchmarking/reporters/markdown_reporter.dart';
import '../src/benchmarking/widgets/benchmark_charts.dart';
import '../src/benchmarking/widgets/distribution_histogram_chart.dart';
import '../src/benchmarking/widgets/percentile_table.dart';
import '../src/benchmarking/widgets/statistical_analysis.dart';

enum DisplayMode { table, charts, distribution }

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  bool _isRunning = false;
  int _iterations = 500;
  String? _errorMessage;
  String? _currentScenario;
  int _completedCount = 0;
  DisplayMode _displayMode = DisplayMode.table;
  BenchmarkReport? _report;

  late final BenchmarkRunner _runner;

  @override
  void initState() {
    super.initState();
    _runner = BenchmarkRunner(
      channelName: 'example_channel',
      methodChannelName: 'native_binder_perf',
    );
  }

  Future<void> _runAllBenchmarks() async {
    if (!NativeBinder.isSupported) {
      setState(() {
        _errorMessage = 'Native bindings not supported on this platform';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _report = null;
      _completedCount = 0;
      _currentScenario = null;
    });

    try {
      final report = await _runner.runAll(
        iterations: _iterations,
        onProgress: (scenarioName, completed, total) {
          setState(() {
            _currentScenario = scenarioName;
            _completedCount = completed;
          });
        },
      );

      setState(() {
        _report = report;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() {
        _isRunning = false;
        _currentScenario = null;
      });
    }
  }

  Future<void> _exportResults(String format) async {
    if (_report == null) return;

    String content;

    switch (format) {
      case 'csv':
        content = CsvReporter.export(_report!);
        break;
      case 'json':
        content = JsonReporter.export(_report!);
        break;
      case 'markdown':
        content = MarkdownReporter.export(_report!, includeDetailedStats: true);
        break;
      default:
        return;
    }

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: content));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$format export copied to clipboard!'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Performance Test'),
        actions: [
          if (_report != null) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              tooltip: 'Export Results',
              onSelected: _exportResults,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
                const PopupMenuItem(
                    value: 'json', child: Text('Export as JSON')),
                const PopupMenuItem(
                    value: 'markdown', child: Text('Export as Markdown')),
              ],
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildConfigCard(theme),
          if (_errorMessage != null) _buildErrorCard(),
          if (_report != null) ...[
            const SizedBox(height: 16),
            _buildSummaryCard(theme),
            const SizedBox(height: 16),
            _buildDisplayModeToggle(),
            const SizedBox(height: 16),
            if (_displayMode == DisplayMode.table)
              _buildResultsTable(theme)
            else if (_displayMode == DisplayMode.charts)
              _buildChartsView()
            else
              _buildDistributionView(),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Benchmark Configuration', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text(
              'Compares NativeBinder (FFI) vs MethodChannel with comprehensive statistical analysis. '
              'Includes extended percentiles (P10-P99.9), distribution histograms, skewness, kurtosis, '
              'outlier detection, and detailed timing breakdowns.',
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Iterations: '),
                    DropdownButton<int>(
                      value: _iterations,
                      items: const [
                        DropdownMenuItem(value: 100, child: Text('100')),
                        DropdownMenuItem(value: 250, child: Text('250')),
                        DropdownMenuItem(value: 500, child: Text('500')),
                        DropdownMenuItem(value: 1000, child: Text('1,000')),
                        DropdownMenuItem(value: 2000, child: Text('2,000')),
                      ],
                      onChanged: _isRunning
                          ? null
                          : (v) {
                              if (v != null) setState(() => _iterations = v);
                            },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isRunning ? null : _runAllBenchmarks,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning
                  ? 'Running ($_completedCount/${_runner.scenarios.length})...'
                  : 'Run All Benchmarks'),
            ),
            if (_isRunning && _currentScenario != null) ...[
              const SizedBox(height: 8),
              Text('Testing: $_currentScenario',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900)),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    if (_report == null) return const SizedBox();

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryTile(
                  label: 'Avg Speedup',
                  value: '${_report!.avgSpeedup.toStringAsFixed(1)}x',
                  icon: Icons.speed,
                  color: Colors.green,
                ),
                _SummaryTile(
                  label: 'Max Speedup',
                  value: '${_report!.maxSpeedup.toStringAsFixed(1)}x',
                  subtitle: _report!.maxSpeedupScenario,
                  icon: Icons.rocket_launch,
                  color: Colors.blue,
                ),
                _SummaryTile(
                  label: 'Platform',
                  value: _report!.deviceInfo.platform.toUpperCase(),
                  icon: Icons.phone_android,
                  color: Colors.purple,
                ),
                _SummaryTile(
                  label: 'Test Date',
                  value:
                      '${_report!.timestamp.month}/${_report!.timestamp.day}',
                  subtitle:
                      '${_report!.timestamp.hour.toString().padLeft(2, '0')}:${_report!.timestamp.minute.toString().padLeft(2, '0')}',
                  icon: Icons.calendar_today,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayModeToggle() {
    return SegmentedButton<DisplayMode>(
      segments: const [
        ButtonSegment(
            value: DisplayMode.table,
            label: Text('Table'),
            icon: Icon(Icons.table_chart)),
        ButtonSegment(
            value: DisplayMode.charts,
            label: Text('Charts'),
            icon: Icon(Icons.bar_chart)),
        ButtonSegment(
            value: DisplayMode.distribution,
            label: Text('Distribution'),
            icon: Icon(Icons.analytics)),
      ],
      selected: {_displayMode},
      onSelectionChanged: (Set<DisplayMode> newSelection) {
        setState(() => _displayMode = newSelection.first);
      },
    );
  }

  Widget _buildResultsTable(ThemeData theme) {
    if (_report == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detailed Results', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Mean ± Standard Deviation (µs). P95/P99 show 95th and 99th percentile values.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildEnhancedTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      columnWidths: const {
        0: FixedColumnWidth(120),
        1: FixedColumnWidth(100),
        2: FixedColumnWidth(80),
        3: FixedColumnWidth(100),
        4: FixedColumnWidth(80),
        5: FixedColumnWidth(70),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.blue.shade100),
          children: const [
            _TableHeader('Scenario'),
            _TableHeader('NB Mean±SD'),
            _TableHeader('MC Mean±SD'),
            _TableHeader('NB P95/P99'),
            _TableHeader('MC P95/P99'),
            _TableHeader('Speedup'),
          ],
        ),
        if (_report != null)
          ..._report!.results.map((r) {
            final nbStats = r.nativeBinderTotal;
            final mcStats = r.methodChannelTotal;

            return TableRow(
              decoration: const BoxDecoration(color: Colors.white),
              children: [
                _TableCell(r.name),
                _TableCell(
                    '${nbStats.mean.toStringAsFixed(1)}±${nbStats.stdDev.toStringAsFixed(1)}'),
                _TableCell(
                    '${mcStats.mean.toStringAsFixed(1)}±${mcStats.stdDev.toStringAsFixed(1)}'),
                _TableCell(
                    '${nbStats.p95.toStringAsFixed(1)}/${nbStats.p99.toStringAsFixed(1)}'),
                _TableCell(
                    '${mcStats.p95.toStringAsFixed(1)}/${mcStats.p99.toStringAsFixed(1)}'),
                _TableCell('${r.speedup.toStringAsFixed(1)}x', bold: true),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildChartsView() {
    if (_report == null) return const SizedBox();

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TimingBreakdownChart(results: _report!.results),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SpeedupComparisonChart(results: _report!.results),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatisticalDistributionChart(results: _report!.results),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionView() {
    if (_report == null) return const SizedBox();

    return Column(
      children: [
        // Statistical summary cards
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatisticalSummaryCards(report: _report!),
          ),
        ),
        const SizedBox(height: 16),
        // Percentile summary table
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PercentileSummaryTable(results: _report!.results),
          ),
        ),
        const SizedBox(height: 16),
        // Distribution histograms for each scenario
        if (_report!.results.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DistributionHistogramChart(
                result: _report!.results.first,
                showNativeBinder: true,
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Detailed percentile distribution table
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PercentileDistributionTable(results: _report!.results),
          ),
        ),
        const SizedBox(height: 16),
        // Statistical analysis section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatisticalAnalysisSection(results: _report!.results),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (subtitle != null)
            Text(subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    )),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;

  const _TableCell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}
