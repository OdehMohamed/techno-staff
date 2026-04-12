import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:techno_staff/shared/widgets/chart_legend.dart';

class DashboardLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const DashboardLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text("No data");
    }

    final createdSpots = <FlSpot>[];
    final completedSpots = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      createdSpots.add(
        FlSpot(i.toDouble(), (data[i]['created'] as int).toDouble()),
      );

      completedSpots.add(
        FlSpot(i.toDouble(), (data[i]['completed'] as int).toDouble()),
      );
    }

    return Column(
      children: [
        ChartLegend(
          items: [
            ChartLegendItem(color: Colors.blue, label: 'created_tasks'.tr()),
            ChartLegendItem(color: Colors.green, label: 'completed_tasks'.tr()),
          ],
        ),

        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: createdSpots,
                  isCurved: true,
                  color: Colors.blue,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: completedSpots,
                  isCurved: true,
                  color: Colors.green,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
