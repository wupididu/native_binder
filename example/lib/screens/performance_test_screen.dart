import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_binder/native_binder.dart';

class _BenchmarkScenario {
  final String name;
  final String description;
  final String nativeMethod;
  final String channelMethod;
  final dynamic Function() payloadBuilder;

  const _BenchmarkScenario({
    required this.name,
    required this.description,
    required this.nativeMethod,
    required this.channelMethod,
    required this.payloadBuilder,
  });
}

class _BenchmarkResult {
  final String name;
  final String description;
  final double nativeBinderAvg;
  final double methodChannelAvg;
  final double speedup;

  const _BenchmarkResult({
    required this.name,
    required this.description,
    required this.nativeBinderAvg,
    required this.methodChannelAvg,
    required this.speedup,
  });
}

String _generateString(int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final buf = StringBuffer();
  for (int i = 0; i < length; i++) {
    buf.write(chars[i % chars.length]);
  }
  return buf.toString();
}

List<int> _generateIntList(int count) => List.generate(count, (i) => i * 7 + 3);

Map<String, dynamic> _generateMap(int entries) => {
      for (int i = 0; i < entries; i++) 'key_$i': i * 3.14,
    };

Map<String, dynamic> _generateNestedMap(int breadth, int depth) {
  if (depth <= 0) {
    return {'value': 42, 'label': 'leaf'};
  }
  return {
    for (int i = 0; i < breadth; i++)
      'node_$i': _generateNestedMap(breadth, depth - 1),
    'data': List.generate(breadth, (i) => i),
  };
}

class PerformanceTestScreen extends StatefulWidget {
  const PerformanceTestScreen({super.key});

  @override
  State<PerformanceTestScreen> createState() => _PerformanceTestScreenState();
}

class _PerformanceTestScreenState extends State<PerformanceTestScreen> {
  static const platform = MethodChannel('native_binder_perf');
  final _nativeBinder = NativeBinder('example_channel');

  bool _isRunning = false;
  int _iterations = 500;
  String? _errorMessage;
  String? _currentScenario;
  int _completedCount = 0;

  final List<_BenchmarkResult> _results = [];

  late final List<_BenchmarkScenario> _scenarios = [
    _BenchmarkScenario(
      name: 'Int pass-through',
      description: 'Single integer round-trip',
      nativeMethod: 'perfTest',
      channelMethod: 'perfTest',
      payloadBuilder: () => 42,
    ),
    _BenchmarkScenario(
      name: 'String 1 KB',
      description: '~1 KB string echo',
      nativeMethod: 'perfEchoString',
      channelMethod: 'perfEchoString',
      payloadBuilder: () => _generateString(1024),
    ),
    _BenchmarkScenario(
      name: 'String 10 KB',
      description: '~10 KB string echo',
      nativeMethod: 'perfEchoString',
      channelMethod: 'perfEchoString',
      payloadBuilder: () => _generateString(10 * 1024),
    ),
    _BenchmarkScenario(
      name: 'String 100 KB',
      description: '~100 KB string echo',
      nativeMethod: 'perfEchoString',
      channelMethod: 'perfEchoString',
      payloadBuilder: () => _generateString(100 * 1024),
    ),
    _BenchmarkScenario(
      name: 'List 100 ints',
      description: '100-element int list round-trip',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => _generateIntList(100),
    ),
    _BenchmarkScenario(
      name: 'List 1K ints',
      description: '1,000-element int list round-trip',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => _generateIntList(1000),
    ),
    _BenchmarkScenario(
      name: 'List 10K ints',
      description: '10,000-element int list round-trip',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => _generateIntList(10000),
    ),
    _BenchmarkScenario(
      name: 'Map 100 entries',
      description: '100 key-value pairs round-trip',
      nativeMethod: 'perfEchoMap',
      channelMethod: 'perfEchoMap',
      payloadBuilder: () => _generateMap(100),
    ),
    _BenchmarkScenario(
      name: 'Map 1K entries',
      description: '1,000 key-value pairs round-trip',
      nativeMethod: 'perfEchoMap',
      channelMethod: 'perfEchoMap',
      payloadBuilder: () => _generateMap(1000),
    ),
    _BenchmarkScenario(
      name: 'Nested structure',
      description: 'Nested maps+lists (breadth=3, depth=4)',
      nativeMethod: 'perfEchoMap',
      channelMethod: 'perfEchoMap',
      payloadBuilder: () => _generateNestedMap(3, 4),
    ),
    _BenchmarkScenario(
      name: 'Mixed list',
      description: '500 items: strings, ints, doubles, bools, nulls',
      nativeMethod: 'perfEchoList',
      channelMethod: 'perfEchoList',
      payloadBuilder: () => List.generate(500, (i) {
        switch (i % 5) {
          case 0:
            return 'item_$i';
          case 1:
            return i;
          case 2:
            return i * 1.5;
          case 3:
            return i.isEven;
          default:
            return null;
        }
      }),
    ),
  ];

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
      _results.clear();
      _completedCount = 0;
      _currentScenario = null;
    });

    try {
      for (final scenario in _scenarios) {
        setState(() => _currentScenario = scenario.name);

        final payload = scenario.payloadBuilder();

        // Warm up
        for (int i = 0; i < 20; i++) {
          _nativeBinder.invokeMethod(scenario.nativeMethod, payload);
          await platform.invokeMethod(scenario.channelMethod, payload);
        }

        // Benchmark NativeBinder
        final nbStart = DateTime.now().microsecondsSinceEpoch;
        for (int i = 0; i < _iterations; i++) {
          _nativeBinder.invokeMethod(scenario.nativeMethod, payload);
        }
        final nbEnd = DateTime.now().microsecondsSinceEpoch;
        final nbAvg = (nbEnd - nbStart) / _iterations;

        // Benchmark MethodChannel
        final mcStart = DateTime.now().microsecondsSinceEpoch;
        for (int i = 0; i < _iterations; i++) {
          await platform.invokeMethod(scenario.channelMethod, payload);
        }
        final mcEnd = DateTime.now().microsecondsSinceEpoch;
        final mcAvg = (mcEnd - mcStart) / _iterations;

        final speedup = nbAvg > 0 ? mcAvg / nbAvg : double.infinity;

        setState(() {
          _results.add(_BenchmarkResult(
            name: scenario.name,
            description: scenario.description,
            nativeBinderAvg: nbAvg,
            methodChannelAvg: mcAvg,
            speedup: speedup,
          ));
          _completedCount++;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() {
        _isRunning = false;
        _currentScenario = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Benchmark Configuration',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Text(
                    'Compares NativeBinder (FFI) vs MethodChannel across '
                    'different payload sizes and types. Each scenario '
                    'echo-round-trips data to native and back.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Iterations per scenario: '),
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
                        ? 'Running ($_completedCount/${_scenarios.length})...'
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
          ),
          if (_errorMessage != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_errorMessage!,
                    style: TextStyle(color: Colors.red.shade900)),
              ),
            ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSummaryCard(theme),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final avgSpeedup = _results.map((r) => r.speedup).reduce((a, b) => a + b) /
        _results.length;
    final maxSpeedup =
        _results.map((r) => r.speedup).reduce((a, b) => a > b ? a : b);
    final maxScenario = _results.firstWhere((r) => r.speedup == maxSpeedup);

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Avg speedup',
                    value: '${avgSpeedup.toStringAsFixed(1)}x',
                    icon: Icons.speed,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Max speedup',
                    value: '${maxSpeedup.toStringAsFixed(1)}x',
                    subtitle: maxScenario.name,
                    icon: Icons.rocket_launch,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Table(
                border:
                    TableBorder.all(color: Colors.green.shade200, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.green.shade100),
                    children: const [
                      _TableHeader('Scenario'),
                      _TableHeader('FFI (μs)'),
                      _TableHeader('MC (μs)'),
                      _TableHeader('Factor'),
                    ],
                  ),
                  ..._results.map((r) => TableRow(
                        decoration: const BoxDecoration(color: Colors.white),
                        children: [
                          _TableCell(r.name),
                          _TableCell(r.nativeBinderAvg.toStringAsFixed(1)),
                          _TableCell(r.methodChannelAvg.toStringAsFixed(1)),
                          _TableCell('${r.speedup.toStringAsFixed(1)}x',
                              bold: true),
                        ],
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
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
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (subtitle != null)
            Text(subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade500, fontSize: 10)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}
