import 'package:flutter/material.dart';
import '../benchmark_result.dart';

/// Widget displaying detailed percentile distribution in a table format
class PercentileDistributionTable extends StatefulWidget {
  final List<BenchmarkResult> results;

  const PercentileDistributionTable({super.key, required this.results});

  @override
  State<PercentileDistributionTable> createState() => _PercentileDistributionTableState();
}

class _PercentileDistributionTableState extends State<PercentileDistributionTable> {
  int? expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Percentile Distribution',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Detailed percentile breakdown for each scenario',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ...widget.results.asMap().entries.map((entry) {
          final index = entry.key;
          final result = entry.value;
          final isExpanded = expandedIndex == index;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                ListTile(
                  title: Text(result.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(result.description, style: const TextStyle(fontSize: 12)),
                  trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  onTap: () {
                    setState(() {
                      expandedIndex = isExpanded ? null : index;
                    });
                  },
                ),
                if (isExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPercentileTable(result),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPercentileTable(BenchmarkResult result) {
    final percentiles = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99, 0.999, 1.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 40,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 32,
        columns: const [
          DataColumn(
            label: Text('Percentile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          DataColumn(
            label: Text('NativeBinder (µs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true,
          ),
          DataColumn(
            label: Text('MethodChannel (µs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true,
          ),
          DataColumn(
            label: Text('Difference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true,
          ),
          DataColumn(
            label: Text('Speedup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            numeric: true,
          ),
        ],
        rows: percentiles.map((p) {
          final nbValue = result.nativeBinderTotal.getPercentileValue(p);
          final mcValue = result.methodChannelTotal.getPercentileValue(p);
          final diff = mcValue - nbValue;
          final speedup = nbValue > 0 ? mcValue / nbValue : 0.0;

          // Color code the difference
          Color? diffColor;
          if (diff > 100) {
            diffColor = Colors.green.shade100;
          } else if (diff > 50) {
            diffColor = Colors.lightGreen.shade100;
          }

          return DataRow(
            color: WidgetStateProperty.all(diffColor),
            cells: [
              DataCell(Text(_formatPercentile(p), style: const TextStyle(fontSize: 11))),
              DataCell(Text(nbValue.toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
              DataCell(Text(mcValue.toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
              DataCell(
                Text(
                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: diff > 0 ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              DataCell(
                Text(
                  '${speedup.toStringAsFixed(2)}x',
                  style: TextStyle(
                    fontSize: 11,
                    color: speedup > 1 ? Colors.blue.shade700 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatPercentile(double p) {
    if (p == 0) return 'Min (P0)';
    if (p == 1) return 'Max (P100)';
    if (p == 0.5) return 'Median (P50)';
    if (p == 0.999) return 'P99.9';

    final percent = (p * 100).toInt();
    return 'P$percent';
  }
}

/// Summary view showing key percentiles for all scenarios
class PercentileSummaryTable extends StatelessWidget {
  final List<BenchmarkResult> results;

  const PercentileSummaryTable({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Percentile Summary (NativeBinder)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 36,
            dataRowMinHeight: 28,
            dataRowMaxHeight: 28,
            columns: const [
              DataColumn(
                label: Text('Scenario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              DataColumn(
                label: Text('P10', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
              DataColumn(
                label: Text('P25', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
              DataColumn(
                label: Text('P50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
              DataColumn(
                label: Text('P75', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
              DataColumn(
                label: Text('P90', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
              DataColumn(
                label: Text('P95', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
              DataColumn(
                label: Text('P99', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
              DataColumn(
                label: Text('P99.9', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                numeric: true,
              ),
            ],
            rows: results.map((result) {
              final stats = result.nativeBinderTotal;
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(
                        result.name,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(stats.p10.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                  DataCell(Text(stats.p25.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                  DataCell(Text(stats.p50.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                  DataCell(Text(stats.p75.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                  DataCell(Text(stats.p90.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                  DataCell(Text(stats.p95.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                  DataCell(Text(stats.p99.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                  DataCell(Text(stats.p99_9.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
