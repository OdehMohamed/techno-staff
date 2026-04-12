import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  static Future<void> exportDashboardReport({
    required Map<String, int> stats,
    required Map<String, dynamic> extraStats,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Dashboard Report', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 16),

              pw.Text('Total Tasks: ${stats['totalTasks'] ?? 0}'),
              pw.Text('Completed: ${stats['completedTasks'] ?? 0}'),
              pw.Text('In Progress: ${stats['inProgressTasks'] ?? 0}'),
              pw.Text('Pending: ${stats['pendingTasks'] ?? 0}'),

              pw.SizedBox(height: 16),

              pw.Text('Top Performer: ${extraStats['topPerformer'] ?? '-'}'),
              pw.Text('Most Active: ${extraStats['mostActive'] ?? '-'}'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
