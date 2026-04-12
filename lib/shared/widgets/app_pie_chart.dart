import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AppPieChart extends StatelessWidget {
  final int completed;
  final int inProgress;
  final int pending;

  const AppPieChart({
    super.key,
    required this.completed,
    required this.inProgress,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final total = completed + inProgress + pending;

    if (total == 0) {
      return const Center(child: Text('No data'));
    }

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 40,
          sections: [
            _buildSection('Done', completed, Colors.green, total),
            _buildSection('Progress', inProgress, Colors.orange, total),
            _buildSection('Pending', pending, Colors.grey, total),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _buildSection(
    String title,
    int value,
    Color color,
    int total,
  ) {
    final percent = ((value / total) * 100).toStringAsFixed(0);

    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: '$percent%',
      radius: 50,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}
