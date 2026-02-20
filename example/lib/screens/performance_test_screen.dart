import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_binder/native_binder.dart';

class PerformanceTestScreen extends StatefulWidget {
  const PerformanceTestScreen({super.key});

  @override
  State<PerformanceTestScreen> createState() => _PerformanceTestScreenState();
}

class _PerformanceTestScreenState extends State<PerformanceTestScreen> {
  static const platform = MethodChannel('native_binder_perf');

  bool _isRunning = false;
  int _iterations = 1000;

  double? _nativeBinderAvg;
  double? _methodChannelAvg;
  double? _speedupFactor;

  String? _errorMessage;

  Future<void> _runPerformanceTest() async {
    if (!NativeBinder.isSupported) {
      setState(() {
        _errorMessage = 'Native bindings not supported on this platform';
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _nativeBinderAvg = null;
      _methodChannelAvg = null;
      _speedupFactor = null;
    });

    try {
      // Warm up both methods
      for (int i = 0; i < 100; i++) {
        NativeBinder.call<int>('perfTest', i);
        await platform.invokeMethod<int>('perfTest', i);
      }

      // Test NativeBinder
      final nbStart = DateTime.now().microsecondsSinceEpoch;
      for (int i = 0; i < _iterations; i++) {
        NativeBinder.call<int>('perfTest', i);
      }
      final nbEnd = DateTime.now().microsecondsSinceEpoch;
      final nbTotal = nbEnd - nbStart;
      final nbAvg = nbTotal / _iterations;

      // Test MethodChannel
      final mcStart = DateTime.now().microsecondsSinceEpoch;
      for (int i = 0; i < _iterations; i++) {
        await platform.invokeMethod<int>('perfTest', i);
      }
      final mcEnd = DateTime.now().microsecondsSinceEpoch;
      final mcTotal = mcEnd - mcStart;
      final mcAvg = mcTotal / _iterations;

      final speedup = mcAvg / nbAvg;

      setState(() {
        _nativeBinderAvg = nbAvg;
        _methodChannelAvg = mcAvg;
        _speedupFactor = speedup;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Test'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Benchmark Configuration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This test compares the performance of NativeBinder (FFI-based) '
                    'vs MethodChannel (platform channel) by calling a simple native method '
                    'that returns the input value.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Iterations: '),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _iterations,
                        items: const [
                          DropdownMenuItem(value: 100, child: Text('100')),
                          DropdownMenuItem(value: 500, child: Text('500')),
                          DropdownMenuItem(value: 1000, child: Text('1,000')),
                          DropdownMenuItem(value: 5000, child: Text('5,000')),
                          DropdownMenuItem(value: 10000, child: Text('10,000')),
                        ],
                        onChanged: _isRunning
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _iterations = value);
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isRunning ? null : _runPerformanceTest,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isRunning ? 'Running...' : 'Run Benchmark'),
                  ),
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),
          if (_nativeBinderAvg != null &&
              _methodChannelAvg != null &&
              _speedupFactor != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Results',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _ResultRow(
                      label: 'NativeBinder (FFI)',
                      value: '${_nativeBinderAvg!.toStringAsFixed(2)} μs/call',
                      icon: Icons.bolt,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _ResultRow(
                      label: 'MethodChannel',
                      value: '${_methodChannelAvg!.toStringAsFixed(2)} μs/call',
                      icon: Icons.swap_horiz,
                      color: Colors.orange,
                    ),
                    const Divider(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.speed,
                            size: 48,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_speedupFactor!.toStringAsFixed(1)}x faster',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'NativeBinder vs MethodChannel',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'NativeBinder uses FFI (Foreign Function Interface) to make direct '
                      'native calls without the overhead of platform channels, message encoding, '
                      'and async serialization.\n\n'
                      'MethodChannel uses platform channels which involve:\n'
                      '• Message serialization/deserialization\n'
                      '• Async message passing\n'
                      '• Platform thread context switching\n\n'
                      'For synchronous, high-frequency operations, NativeBinder provides '
                      'significantly better performance.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
