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

    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
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
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generated at: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          );
        },
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logo, width: 60, height: 60),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Techno Staff',
                    style: pw.TextStyle(font: boldFont, fontSize: 22),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Employee Monthly Report',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 20),

          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Employee Information',
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Employee: ${employee.name}',
                  style: pw.TextStyle(font: regularFont),
                ),
                pw.Text(
                  'Email: ${employee.email}',
                  style: pw.TextStyle(font: regularFont),
                ),
                pw.Text(
                  'Month: ${DateFormat('yyyy-MM').format(month)}',
                  style: pw.TextStyle(font: regularFont),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          pw.Text('Summary', style: pw.TextStyle(font: boldFont, fontSize: 18)),
          pw.SizedBox(height: 10),

          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatBox('Total', totalTasks, regularFont, boldFont),
              _buildStatBox('Completed', completedTasks, regularFont, boldFont),
              _buildStatBox(
                'In Progress',
                inProgressTasks,
                regularFont,
                boldFont,
              ),
              _buildStatBox('Pending', pendingTasks, regularFont, boldFont),
              _buildStatBox('Overdue', overdueTasks, regularFont, boldFont),
              _buildStatBox(
                'Rate',
                completionRate,
                regularFont,
                boldFont,
                suffix: '%',
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          pw.Text(
            'Tasks Details',
            style: pw.TextStyle(font: boldFont, fontSize: 18),
          ),
          pw.SizedBox(height: 10),

          if (tasks.isEmpty)
            pw.Text(
              'No tasks found for this month.',
              style: pw.TextStyle(font: regularFont),
            )
          else
            _buildTasksTable(
              tasks: tasks,
              regularFont: regularFont,
              boldFont: boldFont,
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

  pw.Widget _buildStatBox(
    String title,
    int value,
    pw.Font regularFont,
    pw.Font boldFont, {
    String suffix = '',
  }) {
    return pw.Container(
      width: 95,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 10,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '$value$suffix',
            style: pw.TextStyle(font: boldFont, fontSize: 14),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTasksTable({
    required List<TaskModel> tasks,
    required pw.Font regularFont,
    required pw.Font boldFont,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.0),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildHeaderCell('Title', boldFont),
            _buildHeaderCell('Priority', boldFont),
            _buildHeaderCell('Status', boldFont),
            _buildHeaderCell('Due Date', boldFont),
          ],
        ),
        ...tasks.map(
          (task) => pw.TableRow(
            children: [
              _buildArabicCell(task.title, regularFont),
              _buildBodyCell(task.priority, regularFont),
              _buildBodyCell(task.status, regularFont),
              _buildBodyCell(
                DateFormat('yyyy-MM-dd').format(task.dueDate),
                regularFont,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeaderCell(String text, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: boldFont, fontSize: 11),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildBodyCell(String text, pw.Font regularFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: regularFont, fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildArabicCell(String text, pw.Font regularFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: regularFont, fontSize: 10),
          textAlign: pw.TextAlign.right,
        ),
      ),
    );
  }
}
