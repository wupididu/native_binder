import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../benchmark_result.dart';

/// Widget displaying timing distribution as a histogram with percentile markers
class DistributionHistogramChart extends StatelessWidget {
  final BenchmarkResult result;
  final bool showNativeBinder;
  final bool showMethodChannel;

  const DistributionHistogramChart({
    super.key,
    required this.result,
    this.showNativeBinder = true,
    this.showMethodChannel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distribution: ${result.name}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Frequency histogram with percentile markers',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: _buildHistogram(),
        ),
        const SizedBox(height: 16),
        _buildLegend(context),
      ],
    );
  }

  Widget _buildHistogram() {
    final stats = showNativeBinder ? result.nativeBinderTotal : result.methodChannelTotal;
    final bins = _calculateHistogramBins(stats.rawValues);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: bins.map((b) => b.count.toDouble()).reduce(math.max) * 1.1,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex >= bins.length) return null;
              final bin = bins[groupIndex];
              return BarTooltipItem(
                '${bin.rangeStart.toStringAsFixed(0)}-${bin.rangeEnd.toStringAsFixed(0)} µs\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                children: [
                  TextSpan(
                    text: 'Count: ${bin.count}',
                    style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10),
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
                final index = value.toInt();
                if (index >= 0 && index < bins.length && index % math.max(1, bins.length ~/ 8) == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      bins[index].rangeStart.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 20,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
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
        barGroups: _buildBarGroups(bins, stats),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: _buildPercentileLines(stats, bins),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<_HistogramBin> bins, TimingStatistics stats) {
    return List.generate(bins.length, (index) {
      final bin = bins[index];
      final midPoint = (bin.rangeStart + bin.rangeEnd) / 2;

      // Color based on position relative to percentiles
      Color barColor;
      if (midPoint <= stats.p25) {
        barColor = Colors.green.withValues(alpha: 0.7);
      } else if (midPoint <= stats.p75) {
        barColor = Colors.blue.withValues(alpha: 0.7);
      } else if (midPoint <= stats.p95) {
        barColor = Colors.orange.withValues(alpha: 0.7);
      } else {
        barColor = Colors.red.withValues(alpha: 0.7);
      }

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: bin.count.toDouble(),
            color: barColor,
            width: 8,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(2),
            ),
          ),
        ],
      );
    });
  }

  List<VerticalLine> _buildPercentileLines(TimingStatistics stats, List<_HistogramBin> bins) {
    final percentiles = {
      'P10': stats.p10,
      'P25': stats.p25,
      'P50': stats.p50,
      'P75': stats.p75,
      'P90': stats.p90,
      'P95': stats.p95,
      'P99': stats.p99,
      'P99.9': stats.p99_9,
    };

    final lines = <VerticalLine>[];

    for (final entry in percentiles.entries) {
      final value = entry.value;
      final binIndex = _findBinIndexForValue(bins, value);

      if (binIndex >= 0) {
        Color lineColor;
        double strokeWidth;

        // Highlight key percentiles
        if (entry.key == 'P50') {
          lineColor = Colors.purple;
          strokeWidth = 2.5;
        } else if (entry.key == 'P95' || entry.key == 'P99') {
          lineColor = Colors.red;
          strokeWidth = 2;
        } else {
          lineColor = Colors.grey.shade700;
          strokeWidth = 1.5;
        }

        lines.add(
          VerticalLine(
            x: binIndex.toDouble(),
            color: lineColor,
            strokeWidth: strokeWidth,
            dashArray: [4, 2],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.all(2),
              style: TextStyle(
                color: lineColor,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              labelResolver: (line) => entry.key,
            ),
          ),
        );
      }
    }

    return lines;
  }

  int _findBinIndexForValue(List<_HistogramBin> bins, double value) {
    for (int i = 0; i < bins.length; i++) {
      if (value >= bins[i].rangeStart && value <= bins[i].rangeEnd) {
        return i;
      }
    }
    return -1;
  }

  List<_HistogramBin> _calculateHistogramBins(List<double> values) {
    if (values.isEmpty) return [];

    final sorted = List<double>.from(values)..sort();
    final min = sorted.first;
    final max = sorted.last;

    // Use Sturges' rule for bin count: k = 1 + log2(n)
    final binCount = math.max(10, math.min(30, (1 + (math.log(values.length) / math.ln2)).ceil()));
    final binWidth = (max - min) / binCount;

    final bins = List<_HistogramBin>.generate(
      binCount,
      (i) => _HistogramBin(
        rangeStart: min + i * binWidth,
        rangeEnd: min + (i + 1) * binWidth,
        count: 0,
      ),
    );

    // Count values in each bin
    for (final value in values) {
      for (final bin in bins) {
        if (value >= bin.rangeStart && (value <= bin.rangeEnd || bin == bins.last)) {
          bin.count++;
          break;
        }
      }
    }

    return bins;
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(color: Colors.green.withValues(alpha: 0.7), label: 'Fast (≤P25)'),
        _LegendItem(color: Colors.blue.withValues(alpha: 0.7), label: 'Normal (P25-P75)'),
        _LegendItem(color: Colors.orange.withValues(alpha: 0.7), label: 'Slow (P75-P95)'),
        _LegendItem(color: Colors.red.withValues(alpha: 0.7), label: 'Very slow (>P95)'),
        const SizedBox(width: 8),
        _LegendItem(color: Colors.purple, label: 'P50 (Median)', isLine: true),
        _LegendItem(color: Colors.red, label: 'P95/P99', isLine: true),
      ],
    );
  }
}

class _HistogramBin {
  final double rangeStart;
  final double rangeEnd;
  int count;

  _HistogramBin({
    required this.rangeStart,
    required this.rangeEnd,
    this.count = 0,
  });
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLine;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(
            width: 16,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          )
        else
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
