import 'package:flutter/material.dart';
import '../benchmark_result.dart';

/// Widget displaying statistical analysis and interpretation of benchmark results
class StatisticalAnalysisSection extends StatelessWidget {
  final List<BenchmarkResult> results;

  const StatisticalAnalysisSection({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistical Analysis',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Distribution characteristics and performance consistency metrics',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...results.map((result) => _StatisticalCard(result: result)),
      ],
    );
  }
}

class _StatisticalCard extends StatelessWidget {
  final BenchmarkResult result;

  const _StatisticalCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final nbStats = result.nativeBinderTotal;
    final mcStats = result.methodChannelTotal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildAnalysisColumn(
                    'NativeBinder',
                    nbStats,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnalysisColumn(
                    'MethodChannel',
                    mcStats,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisColumn(String title, TimingStatistics stats, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricRow(
          icon: Icons.analytics_outlined,
          label: 'Consistency',
          value: stats.consistencyRating,
          color: _getConsistencyColor(stats.coefficientOfVariation),
          tooltip: 'Coefficient of Variation: ${(stats.coefficientOfVariation * 100).toStringAsFixed(1)}%',
        ),
        _MetricRow(
          icon: Icons.show_chart,
          label: 'Distribution',
          value: stats.skewnessInterpretation,
          color: _getSkewnessColor(stats.skewness),
          tooltip: 'Skewness: ${stats.skewness.toStringAsFixed(2)}',
        ),
        _MetricRow(
          icon: Icons.warning_amber_outlined,
          label: 'Outliers',
          value: '${stats.outlierCount} (${(stats.outlierCount / stats.rawValues.length * 100).toStringAsFixed(1)}%)',
          color: _getOutlierColor(stats.outlierCount, stats.rawValues.length),
          tooltip: 'Values beyond P75 + 1.5×IQR or below P25 - 1.5×IQR',
        ),
        _MetricRow(
          icon: Icons.straighten_outlined,
          label: 'IQR',
          value: '${stats.interquartileRange.toStringAsFixed(1)} µs',
          color: Colors.grey.shade700,
          tooltip: 'Interquartile Range (P75 - P25)',
        ),
        _MetricRow(
          icon: Icons.insights_outlined,
          label: 'Kurtosis',
          value: _getKurtosisInterpretation(stats.kurtosis),
          color: _getKurtosisColor(stats.kurtosis),
          tooltip: 'Kurtosis: ${stats.kurtosis.toStringAsFixed(2)} (tailedness measure)',
        ),
      ],
    );
  }

  Color _getConsistencyColor(double cv) {
    if (cv < 0.1) return Colors.green.shade700;
    if (cv < 0.25) return Colors.lightGreen.shade700;
    if (cv < 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _getSkewnessColor(double skewness) {
    if (skewness.abs() < 0.5) return Colors.green.shade700;
    if (skewness.abs() < 1.0) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _getOutlierColor(int count, int total) {
    final percent = count / total;
    if (percent < 0.05) return Colors.green.shade700;
    if (percent < 0.10) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _getKurtosisColor(double kurtosis) {
    if (kurtosis.abs() < 0.5) return Colors.green.shade700;
    if (kurtosis.abs() < 1.0) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  String _getKurtosisInterpretation(double kurtosis) {
    if (kurtosis > 1.0) return 'Heavy tails';
    if (kurtosis > 0.5) return 'Moderate tails';
    if (kurtosis < -1.0) return 'Light tails';
    if (kurtosis < -0.5) return 'Few extremes';
    return 'Normal tails';
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String tooltip;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: tooltip,
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact statistical summary cards
class StatisticalSummaryCards extends StatelessWidget {
  final BenchmarkReport report;

  const StatisticalSummaryCards({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final avgConsistency = _calculateAverageConsistency();
    final avgOutlierPercent = _calculateAverageOutlierPercent();
    final mostConsistent = _findMostConsistentScenario();
    final leastConsistent = _findLeastConsistentScenario();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          title: 'Avg Consistency',
          value: _getConsistencyRating(avgConsistency),
          subtitle: 'CV: ${(avgConsistency * 100).toStringAsFixed(1)}%',
          icon: Icons.analytics_outlined,
          color: _getConsistencyColor(avgConsistency),
        ),
        _SummaryCard(
          title: 'Avg Outliers',
          value: '${avgOutlierPercent.toStringAsFixed(1)}%',
          subtitle: 'Across all tests',
          icon: Icons.warning_amber_outlined,
          color: _getOutlierColor(avgOutlierPercent),
        ),
        _SummaryCard(
          title: 'Most Consistent',
          value: mostConsistent.$1,
          subtitle: 'CV: ${(mostConsistent.$2 * 100).toStringAsFixed(1)}%',
          icon: Icons.check_circle_outline,
          color: Colors.green.shade700,
        ),
        _SummaryCard(
          title: 'Least Consistent',
          value: leastConsistent.$1,
          subtitle: 'CV: ${(leastConsistent.$2 * 100).toStringAsFixed(1)}%',
          icon: Icons.error_outline,
          color: Colors.orange.shade700,
        ),
      ],
    );
  }

  double _calculateAverageConsistency() {
    final cvs = report.results.map((r) => r.nativeBinderTotal.coefficientOfVariation).toList();
    return cvs.reduce((a, b) => a + b) / cvs.length;
  }

  double _calculateAverageOutlierPercent() {
    final percents = report.results.map((r) {
      final stats = r.nativeBinderTotal;
      return stats.outlierCount / stats.rawValues.length;
    }).toList();
    return percents.reduce((a, b) => a + b) / percents.length * 100;
  }

  (String, double) _findMostConsistentScenario() {
    var minCV = double.infinity;
    var scenarioName = '';
    for (final result in report.results) {
      final cv = result.nativeBinderTotal.coefficientOfVariation;
      if (cv < minCV) {
        minCV = cv;
        scenarioName = result.name;
      }
    }
    return (scenarioName, minCV);
  }

  (String, double) _findLeastConsistentScenario() {
    var maxCV = 0.0;
    var scenarioName = '';
    for (final result in report.results) {
      final cv = result.nativeBinderTotal.coefficientOfVariation;
      if (cv > maxCV) {
        maxCV = cv;
        scenarioName = result.name;
      }
    }
    return (scenarioName, maxCV);
  }

  String _getConsistencyRating(double cv) {
    if (cv < 0.1) return 'Excellent';
    if (cv < 0.25) return 'Good';
    if (cv < 0.5) return 'Moderate';
    return 'Variable';
  }

  Color _getConsistencyColor(double cv) {
    if (cv < 0.1) return Colors.green.shade700;
    if (cv < 0.25) return Colors.lightGreen.shade700;
    if (cv < 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color _getOutlierColor(double percent) {
    if (percent < 5) return Colors.green.shade700;
    if (percent < 10) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
