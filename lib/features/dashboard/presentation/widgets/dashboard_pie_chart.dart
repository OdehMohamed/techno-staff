import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:techno_staff/shared/widgets/chart_legend.dart';

class DashboardPieChart extends StatelessWidget {
  final int completed;
  final int inProgress;
  final int pending;

  const DashboardPieChart({
    super.key,
    required this.completed,
    required this.inProgress,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final total = completed + inProgress + pending;

    if (total == 0) {
      return const Center(child: Text("No data"));
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                _buildSection(completed, total, Colors.green, "Completed"),
                _buildSection(inProgress, total, Colors.orange, "In Progress"),
                _buildSection(pending, total, Colors.grey, "Pending"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        ChartLegend(
          items: [
            ChartLegendItem(color: Colors.green, label: 'completed_tasks'.tr()),
            ChartLegendItem(
              color: Colors.orange,
              label: 'in_progress_tasks'.tr(),
            ),
            ChartLegendItem(color: Colors.grey, label: 'pending_tasks'.tr()),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _buildSection(
    int value,
    int total,
    Color color,
    String title,
  ) {
    final percentage = ((value / total) * 100).toStringAsFixed(0);

    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      title: "$percentage%",
      radius: 60,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}
