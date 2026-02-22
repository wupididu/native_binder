import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../benchmark_result.dart';

/// Widget displaying timing breakdown as a stacked bar chart
class TimingBreakdownChart extends StatelessWidget {
  final List<BenchmarkResult> results;

  const TimingBreakdownChart({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timing Breakdown (µs)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _calculateMaxY(),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final result = results[groupIndex];
                    return BarTooltipItem(
                      '${result.name}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: '${rod.toY.toStringAsFixed(1)} µs',
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < results.length) {
                        final name = results[value.toInt()].name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                    reservedSize: 50,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
              barGroups: _buildBarGroups(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateMaxY() / 5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  double _calculateMaxY() {
    double max = 0;
    for (final result in results) {
      final total = result.nativeBinderTotal.mean;
      if (total > max) max = total;
    }
    return max * 1.1; // Add 10% padding
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(results.length, (index) {
      final result = results[index];
      final breakdown = result.nativeBinderBreakdown;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: result.nativeBinderTotal.mean,
            rodStackItems: [
              BarChartRodStackItem(0, breakdown.encode.mean, Colors.blue),
              BarChartRodStackItem(
                breakdown.encode.mean,
                breakdown.encode.mean + breakdown.native.mean,
                Colors.orange,
              ),
              BarChartRodStackItem(
                breakdown.encode.mean + breakdown.native.mean,
                breakdown.encode.mean + breakdown.native.mean + breakdown.decode.mean,
                Colors.green,
              ),
            ],
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: [
        _LegendItem(color: Colors.blue, label: 'Encode (Dart)'),
        _LegendItem(color: Colors.orange, label: 'Native (FFI+exec)'),
        _LegendItem(color: Colors.green, label: 'Decode (Dart)'),
      ],
    );
  }
}

/// Widget displaying speedup comparison as a bar chart
class SpeedupComparisonChart extends StatelessWidget {
  final List<BenchmarkResult> results;

  const SpeedupComparisonChart({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Speedup vs MethodChannel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _calculateMaxY(),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final result = results[groupIndex];
                    return BarTooltipItem(
                      '${result.name}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: '${result.speedup.toStringAsFixed(1)}x faster',
                          style: const TextStyle(fontWeight: FontWeight.normal),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < results.length) {
                        final name = results[value.toInt()].name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                    reservedSize: 50,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toStringAsFixed(0)}x',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
              barGroups: _buildBarGroups(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateMaxY() / 5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateMaxY() {
    double max = 0;
    for (final result in results) {
      if (result.speedup > max) max = result.speedup;
    }
    return (max * 1.1).ceilToDouble(); // Add 10% padding and round up
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(results.length, (index) {
      final result = results[index];

      // Color based on speedup magnitude
      Color barColor;
      if (result.speedup >= 5) {
        barColor = Colors.green;
      } else if (result.speedup >= 3) {
        barColor = Colors.lightGreen;
      } else if (result.speedup >= 2) {
        barColor = Colors.orange;
      } else {
        barColor = Colors.red;
      }

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: result.speedup,
            color: barColor,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }
}

/// Widget displaying statistical distribution as a box plot
class StatisticalDistributionChart extends StatelessWidget {
  final List<BenchmarkResult> results;

  const StatisticalDistributionChart({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timing Distribution (µs)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Box plot showing P10, P25, P50 (median), P75, P90, P95, and P99 values',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _calculateMaxY(),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < results.length) {
                        final name = results[value.toInt()].name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                    reservedSize: 50,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
              barGroups: _buildBoxPlots(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateMaxY() / 5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateMaxY() {
    double max = 0;
    for (final result in results) {
      if (result.nativeBinderTotal.p99 > max) max = result.nativeBinderTotal.p99;
    }
    return max * 1.1;
  }

  List<BarChartGroupData> _buildBoxPlots() {
    return List.generate(results.length, (index) {
      final stats = results[index].nativeBinderTotal;

      return BarChartGroupData(
        x: index,
        barRods: [
          // Whisker (P10 to P90)
          BarChartRodData(
            fromY: stats.p10,
            toY: stats.p90,
            color: Colors.blue.withValues(alpha: 0.25),
            width: 2,
          ),
          // IQR Box (P25 to P75)
          BarChartRodData(
            fromY: stats.p25,
            toY: stats.p75,
            color: Colors.blue.withValues(alpha: 0.6),
            width: 12,
          ),
          // Median line (P50)
          BarChartRodData(
            fromY: stats.p50 - 1,
            toY: stats.p50 + 1,
            color: Colors.orange,
            width: 12,
          ),
          // Upper percentiles (P95 to P99)
          BarChartRodData(
            fromY: stats.p95,
            toY: stats.p99,
            color: Colors.red.withValues(alpha: 0.4),
            width: 4,
          ),
        ],
      );
    });
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
