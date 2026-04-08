import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../auth/domain/models/app_user.dart';
import '../../../tasks/data/models/task_model.dart';

class PdfReportService {
  Future<File> generateEmployeeMonthlyReport({
    required AppUser employee,
    required DateTime month,
    required List<TaskModel> tasks,
  }) async {
    final pdf = pw.Document();

    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );

    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    final completedTasks = tasks
        .where((task) => task.status == 'completed')
        .length;
    final inProgressTasks = tasks
        .where((task) => task.status == 'in_progress')
        .length;
    final pendingTasks = tasks.where((task) => task.status == 'pending').length;
    final overdueTasks = tasks
        .where(
          (task) =>
              task.status != 'completed' &&
              task.dueDate.isBefore(DateTime.now()),
        )
        .length;

    final totalTasks = tasks.length;
    final completionRate = totalTasks == 0
        ? 0
        : ((completedTasks / totalTasks) * 100).round();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) => [
          pw.Text(
            'Employee Monthly Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Employee: ${employee.name}'),
          pw.Text('Email: ${employee.email}'),
          pw.Text('Month: ${DateFormat('yyyy-MM').format(month)}'),
          pw.SizedBox(height: 20),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Total Tasks: $totalTasks'),
                pw.Text('Completed Tasks: $completedTasks'),
                pw.Text('In Progress Tasks: $inProgressTasks'),
                pw.Text('Pending Tasks: $pendingTasks'),
                pw.Text('Overdue Tasks: $overdueTasks'),
                pw.Text('Completion Rate: $completionRate%'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Tasks Details',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (tasks.isEmpty)
            pw.Text('No tasks found for this month.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Title', 'Priority', 'Status', 'Due Date'],
              data: tasks.map((task) {
                return [
                  pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Text(
                      task.title,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(font: regularFont),
                    ),
                  ),
                  pw.Text(
                    task.priority,
                    style: pw.TextStyle(font: regularFont),
                  ),
                  pw.Text(task.status, style: pw.TextStyle(font: regularFont)),
                  pw.Text(
                    DateFormat('yyyy-MM-dd').format(task.dueDate),
                    style: pw.TextStyle(font: regularFont),
                  ),
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: boldFont,
              ),
              cellStyle: pw.TextStyle(font: regularFont),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(8),
            ),
        ],
      ),
    );

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/report_${employee.name}_${DateFormat('yyyy_MM').format(month)}.pdf',
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
