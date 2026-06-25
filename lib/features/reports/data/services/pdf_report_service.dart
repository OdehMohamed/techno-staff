import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/data/models/work_schedule_model.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../tasks/data/models/task_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kNavy = PdfColor.fromInt(0xFF1A3A5C);
const _kGreen = PdfColor.fromInt(0xFF2E7D32);
const _kRed = PdfColor.fromInt(0xFFC62828);
const _kOrange = PdfColor.fromInt(0xFFE65100);
const _kBg = PdfColor.fromInt(0xFFF5F7FA);
const _kBgCard = PdfColor.fromInt(0xFFEEF2F7);
const _kText = PdfColor.fromInt(0xFF1C1C1C);
const _kMuted = PdfColor.fromInt(0xFF6B7280);
const _kDivider = PdfColor.fromInt(0xFFD1D5DB);
const _kTableHeader = PdfColor.fromInt(0xFFDDE3EE);

// ── Localised labels ──────────────────────────────────────────────────────────

class _L {
  final bool ar;
  const _L(String locale) : ar = locale == 'ar';

  // Brand name is fixed — never translated
  String get appName => 'Techno Staff';
  String get reportTitle => ar ? 'تقرير الموظف' : 'Employee Report';
  String get employee => ar ? 'الموظف' : 'Employee';
  String get email => ar ? 'البريد الإلكتروني' : 'Email';
  String get period => ar ? 'الفترة' : 'Period';
  String get generatedAt => ar ? 'صدر في' : 'Generated';
  String get page => ar ? 'صفحة' : 'Page';
  String get of => ar ? 'من' : 'of';

  // Attendance summary
  String get attendanceSummary => ar ? 'ملخص الحضور' : 'Attendance Summary';
  String get attendanceRate => ar ? 'معدل الحضور' : 'Attendance Rate';
  String get daysPresent => ar ? 'أيام الحضور' : 'Present';
  String get daysLate => ar ? 'أيام التأخر' : 'Late';
  String get daysAbsent => ar ? 'أيام الغياب' : 'Absent';
  String get daysOff => ar ? 'أيام الإجازة' : 'Days Off';
  String get daysOffWork => ar ? 'عمل في إجازة' : 'Worked on Day Off';
  String get totalHours => ar ? 'إجمالي ساعات العمل' : 'Total Hours Worked';
  String corrections(int n) => ar
      ? '⚠  $n ${n == 1 ? 'يوم يحتوي على تصحيح إداري' : 'أيام تحتوي على تصحيحات إدارية'}'
      : '⚠  $n ${n == 1 ? 'day has an admin correction' : 'days have admin corrections'}';
  String get naRate => ar ? 'غير متاح' : 'N/A';

  // Task summary
  String get taskPerformance => ar ? 'أداء المهام' : 'Task Performance';
  String get total => ar ? 'الإجمالي' : 'Total';
  String get completed => ar ? 'مكتملة' : 'Completed';
  String get inProgress => ar ? 'جارية' : 'In Progress';
  String get pending => ar ? 'معلقة' : 'Pending';
  String get completionRate => ar ? 'معدل الإنجاز' : 'Completion Rate';
  String get onTime => ar ? 'في الوقت' : 'On Time';
  String get late => ar ? 'متأخر' : 'Late';
  String get openOverdue => ar ? 'متأخر مفتوح' : 'Open Overdue';

  // Performance highlights
  String get highlights => ar ? 'أبرز الأداء' : 'Performance Highlights';
  String get longestDelay => ar ? 'أكثر مهمة تأخيراً' : 'Longest Delayed Task';
  String daysLateLabel(int n) =>
      ar ? '$n ${n == 1 ? 'يوم تأخر' : 'أيام تأخر'}' : '$n ${n == 1 ? 'day late' : 'days late'}';
  String get noHighlights =>
      ar ? 'لا توجد مهام متأخرة في هذه الفترة' : 'No delayed tasks this period';

  // Attention required
  String get attentionRequired => ar ? 'يتطلب الانتباه' : 'Attention Required';
  String get overdueOpen => ar ? 'مهام متأخرة مفتوحة' : 'Open Overdue Tasks';
  String get highPriorityOpen => ar ? 'مهام عالية الأولوية غير مكتملة' : 'High-Priority Unfinished Tasks';
  String get completedLateLabel => ar ? 'مهام مكتملة متأخرة' : 'Tasks Completed Late';
  String get due => ar ? 'مستحقة' : 'Due';
  String get noneLabel => ar ? 'لا يوجد' : 'None';
  String get noAttention =>
      ar ? 'لا توجد مشكلات تستدعي الانتباه' : 'No issues requiring attention';

  // Summary narrative
  String get executiveSummary => ar ? 'الملخص التنفيذي' : 'Executive Summary';

  // Daily attendance table
  String get dailyAttendance => ar ? 'سجل الحضور اليومي' : 'Daily Attendance Record';
  String get dateCol => ar ? 'التاريخ' : 'Date';
  String get statusCol => ar ? 'الحالة' : 'Status';
  String get checkIn => ar ? 'الدخول' : 'Check-in';
  String get checkOut => ar ? 'الخروج' : 'Check-out';
  String get duration => ar ? 'المدة' : 'Duration';
  String get correctedCol => ar ? 'تصحيح' : 'Corrected';

  // Status labels
  String statusLabel(String s) {
    switch (s) {
      case 'present':
        return ar ? 'حاضر' : 'Present';
      case 'late':
        return ar ? 'متأخر' : 'Late';
      case 'absent':
        return ar ? 'غائب' : 'Absent';
      case 'off_day':
        return ar ? 'إجازة' : 'Day Off';
      case 'off_day_work':
        return ar ? 'عمل في إجازة' : 'Worked on Day Off';
      case 'manual':
        return ar ? 'مصحح' : 'Corrected';
      default:
        return s;
    }
  }

  // Priority labels
  String priorityLabel(String p) {
    switch (p) {
      case 'high':
        return ar ? 'عالية' : 'High';
      case 'medium':
        return ar ? 'متوسطة' : 'Medium';
      case 'low':
        return ar ? 'منخفضة' : 'Low';
      default:
        return p;
    }
  }
}

// ── Content-direction helpers ─────────────────────────────────────────────────
// Detect Arabic script to render dynamic content (names, task titles, notes)
// in the correct direction regardless of the overall report language.

bool _containsArabic(String text) =>
    text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

pw.TextDirection _dynamicDir(String text) =>
    _containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

// ── Duration helpers ──────────────────────────────────────────────────────────

String _fmtMinutes(int minutes) {
  if (minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String _fmtTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('HH:mm').format(dt.toLocal());
}

DateTime _endOfDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, 20, 59, 59);

// ── Auto-generated narrative ──────────────────────────────────────────────────

String _buildNarrative({
  required _L l,
  required double? attendanceRate,
  required int completionRate,
  required int openOverdue,
  required int completedLate,
  required int corrections,
}) {
  final bool goodAttendance = attendanceRate == null || attendanceRate >= 80;
  final bool okAttendance =
      attendanceRate != null && attendanceRate >= 60 && attendanceRate < 80;
  final bool goodCompletion = completionRate >= 80;
  final bool hasProblems = openOverdue > 0 || completedLate > 0;

  if (l.ar) {
    final buffer = StringBuffer();
    if (goodAttendance && goodCompletion && !hasProblems) {
      buffer.write('أداء ممتاز في الحضور وإنجاز المهام هذا الشهر.');
    } else if (goodAttendance && !goodCompletion) {
      buffer.write('سجل الحضور جيد.');
      if (hasProblems) {
        buffer.write(' يستدعي إنجاز المهام الانتباه');
        if (openOverdue > 0) buffer.write(' — $openOverdue مهمة متأخرة مفتوحة');
        if (completedLate > 0) buffer.write(openOverdue > 0 ? ' و' : ' —');
        if (completedLate > 0) buffer.write(' $completedLate مهمة مكتملة متأخرة');
        buffer.write('.');
      }
    } else if (okAttendance) {
      buffer.write('يحتاج سجل الحضور إلى تحسين.');
      if (!goodCompletion && hasProblems) {
        buffer.write(' كذلك يتطلب إنجاز المهام الانتباه.');
      } else if (goodCompletion) {
        buffer.write(' إنجاز المهام جيد.');
      }
    } else if (!goodAttendance) {
      buffer.write('يستدعي الحضور اهتماماً عاجلاً.');
      if (goodCompletion) {
        buffer.write(' معدل إنجاز المهام مقبول رغم ذلك.');
      }
    } else {
      buffer.write('أداء جيد هذا الشهر بشكل عام.');
    }
    if (corrections > 0) {
      buffer.write(' تمت مراجعة $corrections ${corrections == 1 ? 'يوم' : 'أيام'} يدوياً.');
    }
    return buffer.toString();
  } else {
    final buffer = StringBuffer();
    if (goodAttendance && goodCompletion && !hasProblems) {
      buffer.write('Excellent attendance and task completion performance this month.');
    } else if (goodAttendance && !goodCompletion) {
      buffer.write('Attendance record is good.');
      if (hasProblems) {
        buffer.write(' Task completion requires attention');
        if (openOverdue > 0) buffer.write(' — $openOverdue task${openOverdue == 1 ? '' : 's'} overdue');
        if (completedLate > 0) {
          buffer.write(openOverdue > 0 ? ' and' : ' —');
          buffer.write(' $completedLate completed late');
        }
        buffer.write('.');
      } else {
        buffer.write(' Completion rate should be improved.');
      }
    } else if (okAttendance) {
      buffer.write('Attendance requires improvement.');
      if (!goodCompletion && hasProblems) {
        buffer.write(' Task completion also needs attention.');
      } else if (goodCompletion) {
        buffer.write(' Task completion performance is solid.');
      }
    } else if (!goodAttendance) {
      buffer.write('Attendance requires immediate attention.');
      if (goodCompletion) buffer.write(' Task completion is strong despite this.');
    } else {
      buffer.write('Overall performance is satisfactory this month.');
    }
    if (corrections > 0) {
      buffer.write(
          ' $corrections ${corrections == 1 ? 'day has' : 'days have'} been manually corrected.');
    }
    return buffer.toString();
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

class PdfReportService {
  Future<File> generateEmployeeMonthlyReport({
    required AppUser employee,
    required DateTime startDate,
    required DateTime endDate,
    required List<TaskModel> tasks,
    required List<AttendanceModel> monthlyRecords,
    required WorkScheduleModel? schedule,
    required String locale,
  }) async {
    final l = _L(locale);
    final isAr = l.ar;
    final dir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final textAlign = isAr ? pw.TextAlign.right : pw.TextAlign.left;

    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
    );

    final now = DateTime.now();
    final dateFmt = DateFormat('d MMM yyyy', locale);
    final monthLabel = startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day
        ? dateFmt.format(startDate)
        : '${dateFmt.format(startDate)} – ${dateFmt.format(endDate)}';
    final generatedLabel = DateFormat('d MMMM yyyy  HH:mm', locale).format(now);

    // ── Attendance metrics ────────────────────────────────────────────────────
    final daysPresent = monthlyRecords
        .where((r) => r.status == 'present' || r.status == 'manual')
        .length;
    final daysLate = monthlyRecords.where((r) => r.status == 'late').length;
    final daysAbsent = monthlyRecords.where((r) => r.status == 'absent').length;
    final daysOff = monthlyRecords.where((r) => r.status == 'off_day').length;
    final daysOffWork =
        monthlyRecords.where((r) => r.status == 'off_day_work').length;
    final correctionCount = monthlyRecords.where((r) => r.isCorrected).length;
    final totalMinutes = monthlyRecords.fold<int>(
        0, (s, r) => s + r.totalDurationMinutes);
    final daysWorked = daysPresent + daysLate + daysOffWork;

    double? attendanceRate;
    if (schedule != null) {
      final workingDays = _countWorkingDaysInRange(schedule, startDate, endDate);
      if (workingDays > 0) {
        attendanceRate = (daysWorked / workingDays * 100).clamp(0.0, 100.0);
      }
    }

    // ── Task metrics ──────────────────────────────────────────────────────────
    final completedTasks =
        tasks.where((t) => t.status == 'completed').length;
    final inProgressTasks =
        tasks.where((t) => t.status == 'in_progress').length;
    final pendingTasks = tasks.where((t) => t.status == 'pending').length;
    final totalTasks = tasks.length;
    final completionRate = totalTasks == 0
        ? 0
        : ((completedTasks / totalTasks) * 100).round();

    final completedOnTime = tasks.where((t) {
      return t.status == 'completed' &&
          t.completedAt != null &&
          !t.completedAt!.isAfter(_endOfDay(t.dueDate));
    }).length;
    final completedLate = tasks.where((t) {
      return t.status == 'completed' &&
          t.completedAt != null &&
          t.completedAt!.isAfter(_endOfDay(t.dueDate));
    }).length;
    final openOverdue = tasks.where((t) {
      return t.status != 'completed' &&
          DateTime.now().isAfter(_endOfDay(t.dueDate));
    }).length;

    // ── Attention lists ───────────────────────────────────────────────────────
    final overdueList = tasks
        .where((t) =>
            t.status != 'completed' &&
            DateTime.now().isAfter(_endOfDay(t.dueDate)))
        .toList();
    final highPriorityList = tasks
        .where((t) => t.priority == 'high' && t.status != 'completed')
        .where((t) => !DateTime.now().isAfter(_endOfDay(t.dueDate)))
        .toList();
    final lateCompletedList = tasks
        .where((t) =>
            t.status == 'completed' &&
            t.completedAt != null &&
            t.completedAt!.isAfter(_endOfDay(t.dueDate)))
        .toList();

    // Longest delay
    TaskModel? longestDelayed;
    int maxDelayDays = 0;
    for (final t in lateCompletedList) {
      final delay = t.completedAt!
          .difference(_endOfDay(t.dueDate))
          .inDays;
      if (delay > maxDelayDays) {
        maxDelayDays = delay;
        longestDelayed = t;
      }
    }

    // ── Narrative ─────────────────────────────────────────────────────────────
    final narrative = _buildNarrative(
      l: l,
      attendanceRate: attendanceRate,
      completionRate: completionRate,
      openOverdue: openOverdue,
      completedLate: completedLate,
      corrections: correctionCount,
    );

    // ── Sorted daily records ──────────────────────────────────────────────────
    final sortedRecords = [...monthlyRecords]
      ..sort((a, b) => a.date.compareTo(b.date));

    // ── Build PDF ─────────────────────────────────────────────────────────────
    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    pw.Widget footer(pw.Context ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${l.generatedAt}: $generatedLabel',
                style: pw.TextStyle(
                    font: regularFont, fontSize: 7.5, color: _kMuted),
              ),
              pw.Text(
                '${l.page} ${ctx.pageNumber} ${l.of} ${ctx.pagesCount}',
                style: pw.TextStyle(
                    font: regularFont, fontSize: 7.5, color: _kMuted),
              ),
            ],
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        theme: theme,
        footer: footer,
        textDirection: dir,
        build: (ctx) => [
          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(
            logo: logo,
            l: l,
            employeeName: employee.name,
            employeeEmail: employee.email,
            monthLabel: monthLabel,
            generatedLabel: generatedLabel,
            boldFont: boldFont,
            regularFont: regularFont,
            isAr: isAr,
          ),
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 12),

          // ── Attendance summary ───────────────────────────────────────────
          _sectionTitle(l.attendanceSummary, boldFont),
          pw.SizedBox(height: 6),
          _attendanceSummaryBlock(
            l: l,
            attendanceRate: attendanceRate,
            daysPresent: daysPresent,
            daysLate: daysLate,
            daysAbsent: daysAbsent,
            daysOff: daysOff,
            daysOffWork: daysOffWork,
            totalMinutes: totalMinutes,
            correctionCount: correctionCount,
            boldFont: boldFont,
            regularFont: regularFont,
            isAr: isAr,
          ),
          pw.SizedBox(height: 12),

          // ── Task performance ─────────────────────────────────────────────
          _sectionTitle(l.taskPerformance, boldFont),
          pw.SizedBox(height: 6),
          _taskSummaryBlock(
            l: l,
            total: totalTasks,
            completed: completedTasks,
            inProgress: inProgressTasks,
            pending: pendingTasks,
            rate: completionRate,
            onTime: completedOnTime,
            late: completedLate,
            overdue: openOverdue,
            boldFont: boldFont,
            regularFont: regularFont,
          ),
          pw.SizedBox(height: 12),

          // ── Performance highlights ───────────────────────────────────────
          _sectionTitle(l.highlights, boldFont),
          pw.SizedBox(height: 6),
          _highlightsBlock(
            l: l,
            longestDelayed: longestDelayed,
            maxDelayDays: maxDelayDays,
            boldFont: boldFont,
            regularFont: regularFont,
            locale: locale,
          ),
          pw.SizedBox(height: 12),

          // ── Attention required ───────────────────────────────────────────
          _sectionTitle(l.attentionRequired, boldFont),
          pw.SizedBox(height: 6),
          _attentionBlock(
            l: l,
            overdueList: overdueList,
            highPriorityList: highPriorityList,
            lateCompletedList: lateCompletedList,
            boldFont: boldFont,
            regularFont: regularFont,
            locale: locale,
          ),
          pw.SizedBox(height: 12),

          // ── Executive summary ────────────────────────────────────────────
          _sectionTitle(l.executiveSummary, boldFont),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFEEF6FF),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _kNavy.shade(0.3), width: 0.8),
            ),
            child: pw.Text(
              narrative,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 9.5,
                color: _kText,
                lineSpacing: 2,
              ),
              textAlign: textAlign,
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Daily attendance table ───────────────────────────────────────
          if (sortedRecords.isNotEmpty) ...[
            _sectionTitle(l.dailyAttendance, boldFont),
            pw.SizedBox(height: 6),
            _dailyAttendanceTable(
              l: l,
              records: sortedRecords,
              boldFont: boldFont,
              regularFont: regularFont,
              locale: locale,
              isAr: isAr,
            ),
          ],
        ],
      ),
    );

    final directory = await getTemporaryDirectory();
    final rangeTag =
        '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}';
    final file = File(
      '${directory.path}/report_${employee.name.replaceAll(' ', '_')}'
      '_$rangeTag.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Header ────────────────────────────────────────────────────────────────

  pw.Widget _buildHeader({
    required pw.MemoryImage logo,
    required _L l,
    required String employeeName,
    required String employeeEmail,
    required String monthLabel,
    required String generatedLabel,
    required pw.Font boldFont,
    required pw.Font regularFont,
    required bool isAr,
  }) {
    final logoWidget = pw.Image(logo, width: 48, height: 48);
    final brandBlock = pw.Column(
      crossAxisAlignment:
          isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(l.appName,
            style: pw.TextStyle(font: boldFont, fontSize: 20, color: _kNavy)),
        pw.SizedBox(height: 2),
        pw.Text(l.reportTitle,
            style: pw.TextStyle(font: regularFont, fontSize: 11, color: _kMuted)),
      ],
    );

    final brandRow = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: isAr ? [brandBlock, logoWidget] : [logoWidget, brandBlock],
    );

    // 2×2 info grid — each cell: label on top, value below with auto-direction
    final infoGrid = pw.Table(
      border: pw.TableBorder.all(color: _kDivider, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(children: [
          _infoCell(l.employee, employeeName, regularFont, boldFont),
          _infoCell(l.period, monthLabel, regularFont, boldFont),
        ]),
        pw.TableRow(children: [
          // Email is always LTR (ASCII)
          _infoCell(l.email, employeeEmail, regularFont, boldFont,
              alwaysLtr: true),
          _infoCell(l.generatedAt, generatedLabel, regularFont, boldFont),
        ]),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        brandRow,
        pw.SizedBox(height: 8),
        infoGrid,
      ],
    );
  }

  // Stacked label + value cell. Value direction is auto-detected unless
  // alwaysLtr is true (used for email addresses).
  pw.Widget _infoCell(
    String label,
    String value,
    pw.Font regular,
    pw.Font bold, {
    bool alwaysLtr = false,
  }) {
    final contentDir =
        alwaysLtr ? pw.TextDirection.ltr : _dynamicDir(value);
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: regular, fontSize: 8, color: _kMuted)),
          pw.SizedBox(height: 3),
          pw.Directionality(
            textDirection: contentDir,
            child: pw.Text(value,
                style:
                    pw.TextStyle(font: bold, fontSize: 9.5, color: _kText)),
          ),
        ],
      ),
    );
  }

  // ── Attendance summary block ──────────────────────────────────────────────

  pw.Widget _attendanceSummaryBlock({
    required _L l,
    required double? attendanceRate,
    required int daysPresent,
    required int daysLate,
    required int daysAbsent,
    required int daysOff,
    required int daysOffWork,
    required int totalMinutes,
    required int correctionCount,
    required pw.Font boldFont,
    required pw.Font regularFont,
    required bool isAr,
  }) {
    final rateInt = attendanceRate?.round() ?? 0;
    final barColor = attendanceRate == null
        ? _kMuted
        : attendanceRate >= 80
            ? _kGreen
            : attendanceRate >= 60
                ? _kOrange
                : _kRed;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _kBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Rate row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(l.attendanceRate,
                  style: pw.TextStyle(
                      font: boldFont, fontSize: 9.5, color: _kText)),
              pw.Text(
                attendanceRate == null ? l.naRate : '$rateInt%',
                style: pw.TextStyle(font: boldFont, fontSize: 13, color: barColor),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          // Rate bar
          pw.ClipRRect(
            horizontalRadius: 3,
            verticalRadius: 3,
            child: pw.Row(children: [
              if (rateInt > 0)
                pw.Flexible(
                  flex: rateInt,
                  child: pw.Container(height: 5, color: barColor),
                ),
              if (rateInt < 100)
                pw.Flexible(
                  flex: 100 - rateInt,
                  child: pw.Container(height: 5, color: _kDivider),
                ),
            ]),
          ),
          pw.SizedBox(height: 8),
          // Day breakdown
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _attendanceChip(l.daysPresent, daysPresent, _kGreen, regularFont,
                  boldFont),
              if (daysLate > 0)
                _attendanceChip(
                    l.daysLate, daysLate, _kOrange, regularFont, boldFont),
              _attendanceChip(l.daysAbsent, daysAbsent, _kRed, regularFont,
                  boldFont),
              if (daysOff > 0)
                _attendanceChip(
                    l.daysOff, daysOff, _kMuted, regularFont, boldFont),
              if (daysOffWork > 0)
                _attendanceChip(
                    l.daysOffWork, daysOffWork, _kNavy, regularFont, boldFont),
              _attendanceChip(l.totalHours, _fmtMinutes(totalMinutes), _kNavy,
                  regularFont, boldFont),
            ],
          ),
          if (correctionCount > 0) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              l.corrections(correctionCount),
              style: pw.TextStyle(
                  font: regularFont, fontSize: 8.5, color: _kOrange),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _attendanceChip(
    String label,
    dynamic value,
    PdfColor color,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _kDivider, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$value',
              style: pw.TextStyle(font: bold, fontSize: 11, color: color)),
          pw.Text(label,
              style: pw.TextStyle(font: regular, fontSize: 7.5, color: _kMuted)),
        ],
      ),
    );
  }

  // ── Task summary block ────────────────────────────────────────────────────

  pw.Widget _taskSummaryBlock({
    required _L l,
    required int total,
    required int completed,
    required int inProgress,
    required int pending,
    required int rate,
    required int onTime,
    required int late,
    required int overdue,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final barColor =
        rate >= 80 ? _kGreen : rate >= 60 ? _kOrange : _kRed;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _kBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            _taskStatCell(l.total, total.toString(), boldFont, regularFont),
            pw.SizedBox(width: 5),
            _taskStatCell(l.completed, completed.toString(), boldFont,
                regularFont, accent: _kGreen),
            pw.SizedBox(width: 5),
            _taskStatCell(l.inProgress, inProgress.toString(), boldFont,
                regularFont, accent: _kOrange),
            pw.SizedBox(width: 5),
            _taskStatCell(l.pending, pending.toString(), boldFont,
                regularFont),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${l.completionRate}: $rate%',
                  style:
                      pw.TextStyle(font: boldFont, fontSize: 9, color: _kText)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.ClipRRect(
            horizontalRadius: 3,
            verticalRadius: 3,
            child: pw.Row(children: [
              if (rate > 0)
                pw.Flexible(
                    flex: rate,
                    child: pw.Container(height: 5, color: barColor)),
              if (rate < 100)
                pw.Flexible(
                    flex: 100 - rate,
                    child: pw.Container(height: 5, color: _kDivider)),
            ]),
          ),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            _miniDelivery(l.onTime, onTime.toString(), _kGreen, regularFont,
                boldFont),
            pw.SizedBox(width: 5),
            _miniDelivery(
                l.late,
                late.toString(),
                late > 0 ? _kOrange : _kMuted,
                regularFont,
                boldFont),
            pw.SizedBox(width: 5),
            _miniDelivery(
                l.openOverdue,
                overdue.toString(),
                overdue > 0 ? _kRed : _kMuted,
                regularFont,
                boldFont),
          ]),
        ],
      ),
    );
  }

  pw.Widget _taskStatCell(
    String label,
    String value,
    pw.Font bold,
    pw.Font regular, {
    PdfColor? accent,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: _kBgCard,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    font: bold, fontSize: 15, color: accent ?? _kNavy),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: _kMuted),
                textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
  }

  pw.Widget _miniDelivery(
    String label,
    String value,
    PdfColor color,
    pw.Font regular,
    pw.Font bold,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: _kBgCard,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(value,
                style: pw.TextStyle(font: bold, fontSize: 11, color: color)),
            pw.SizedBox(width: 3),
            pw.Text(label,
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: _kMuted)),
          ],
        ),
      ),
    );
  }

  // ── Highlights block ──────────────────────────────────────────────────────

  pw.Widget _highlightsBlock({
    required _L l,
    required TaskModel? longestDelayed,
    required int maxDelayDays,
    required pw.Font boldFont,
    required pw.Font regularFont,
    required String locale,
  }) {
    if (longestDelayed == null) {
      return _emptyBox(l.noHighlights, regularFont);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: _kBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(l.longestDelay,
              style:
                  pw.TextStyle(font: boldFont, fontSize: 8.5, color: _kMuted)),
          pw.SizedBox(height: 3),
          pw.Directionality(
            textDirection: _dynamicDir(longestDelayed.title),
            child: pw.Text(longestDelayed.title,
                style: pw.TextStyle(
                    font: boldFont, fontSize: 9.5, color: _kText)),
          ),
          pw.SizedBox(height: 2),
          pw.Text(l.daysLateLabel(maxDelayDays),
              style: pw.TextStyle(font: regularFont, fontSize: 8.5, color: _kOrange)),
        ],
      ),
    );
  }

  // ── Attention block ───────────────────────────────────────────────────────

  pw.Widget _attentionBlock({
    required _L l,
    required List<TaskModel> overdueList,
    required List<TaskModel> highPriorityList,
    required List<TaskModel> lateCompletedList,
    required pw.Font boldFont,
    required pw.Font regularFont,
    required String locale,
  }) {
    final hasAnything = overdueList.isNotEmpty ||
        highPriorityList.isNotEmpty ||
        lateCompletedList.isNotEmpty;

    if (!hasAnything) {
      return _emptyBox(l.noAttention, regularFont, color: _kGreen);
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: _kBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (overdueList.isNotEmpty) ...[
            _attentionGroup(l.overdueOpen, overdueList, boldFont, regularFont,
                _kRed, locale, l),
            pw.SizedBox(height: 8),
          ],
          if (highPriorityList.isNotEmpty) ...[
            _attentionGroup(l.highPriorityOpen, highPriorityList, boldFont,
                regularFont, _kOrange, locale, l),
            pw.SizedBox(height: 8),
          ],
          if (lateCompletedList.isNotEmpty)
            _attentionGroup(l.completedLateLabel, lateCompletedList, boldFont,
                regularFont, _kOrange, locale, l),
        ],
      ),
    );
  }

  pw.Widget _attentionGroup(
    String groupTitle,
    List<TaskModel> items,
    pw.Font boldFont,
    pw.Font regularFont,
    PdfColor accent,
    String locale,
    _L l,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(groupTitle,
            style:
                pw.TextStyle(font: boldFont, fontSize: 8.5, color: accent)),
        pw.SizedBox(height: 3),
        ...items.take(5).map((t) {
          final dueStr = DateFormat('d MMM yyyy', locale).format(t.dueDate);
          final titleDir = _dynamicDir(t.title);
          // Wrap the entire item in the title's direction so the bullet
          // sits on the correct side when content is Arabic.
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Directionality(
              textDirection: titleDir,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• ',
                          style: pw.TextStyle(
                              font: boldFont, fontSize: 8, color: accent)),
                      pw.Expanded(
                        child: pw.Text(
                          t.title,
                          style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8.5,
                              color: _kText),
                        ),
                      ),
                    ],
                  ),
                  // Due-date metadata is always in report-locale direction
                  pw.Directionality(
                    textDirection:
                        _containsArabic(l.due) ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(
                          left: 10, right: 10, top: 1),
                      child: pw.Text(
                        '${l.due}: $dueStr',
                        style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 8,
                            color: _kMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (items.length > 5)
          pw.Text('… +${items.length - 5} more',
              style:
                  pw.TextStyle(font: regularFont, fontSize: 8, color: _kMuted)),
      ],
    );
  }

  // ── Daily attendance table ────────────────────────────────────────────────

  pw.Widget _dailyAttendanceTable({
    required _L l,
    required List<AttendanceModel> records,
    required pw.Font boldFont,
    required pw.Font regularFont,
    required String locale,
    required bool isAr,
  }) {
    final headers = [
      l.dateCol,
      l.statusCol,
      l.checkIn,
      l.checkOut,
      l.duration,
      l.correctedCol,
    ];

    // Column widths: date, status, in, out, duration, corrected
    const widths = {
      0: pw.FlexColumnWidth(2.0),
      1: pw.FlexColumnWidth(1.8),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(1.2),
      4: pw.FlexColumnWidth(1.2),
      5: pw.FlexColumnWidth(1.0),
    };

    return pw.Table(
      border: pw.TableBorder.all(color: _kDivider, width: 0.5),
      columnWidths: widths,
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kTableHeader),
          children: headers
              .map((h) => _tableCell(h, boldFont, isHeader: true))
              .toList(),
        ),
        // Data rows
        ...records.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isEven = i % 2 == 0;

          final dateStr = DateFormat('d MMM', locale)
              .format(DateTime.parse(r.date));
          final statusStr = l.statusLabel(r.status);
          final checkIn = _fmtTime(r.checkInAt);
          final checkOut = _fmtTime(r.checkOutAt);
          final dur = _fmtMinutes(r.totalDurationMinutes);
          final correctedStr = r.isCorrected ? '✎' : '';

          final statusColor = _statusColor(r.status);
          final rowBg = isEven ? PdfColors.white : _kBg;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              _tableCell(dateStr, regularFont),
              _tableCellColored(statusStr, regularFont, statusColor),
              _tableCellLtr(checkIn, regularFont),
              _tableCellLtr(checkOut, regularFont),
              _tableCellLtr(dur, regularFont),
              _tableCell(correctedStr, regularFont,
                  color: r.isCorrected ? _kOrange : null),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 8 : 7.5,
          color: color ?? (isHeader ? _kNavy : _kText),
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _tableCellColored(String text, pw.Font font, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 7.5, color: color),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Numbers/times are always LTR regardless of locale
  pw.Widget _tableCellLtr(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Text(
          text,
          style: pw.TextStyle(font: font, fontSize: 7.5, color: _kText),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  PdfColor _statusColor(String status) {
    switch (status) {
      case 'present':
        return _kGreen;
      case 'late':
        return _kOrange;
      case 'absent':
        return _kRed;
      case 'off_day':
        return _kMuted;
      case 'off_day_work':
        return _kNavy;
      case 'manual':
        return _kOrange;
      default:
        return _kText;
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  pw.Widget _emptyBox(String text, pw.Font regular,
      {PdfColor color = _kMuted}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _kBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(font: regular, fontSize: 8.5, color: color)),
    );
  }
}

// ── Helpers outside class ─────────────────────────────────────────────────────

pw.Widget _sectionTitle(String text, pw.Font boldFont) {
  return pw.Text(
    text,
    style: pw.TextStyle(font: boldFont, fontSize: 10, color: _kNavy),
  );
}

pw.Widget _divider() =>
    pw.Divider(color: _kDivider, thickness: 0.8);

int _countWorkingDaysInRange(
  WorkScheduleModel schedule,
  DateTime start,
  DateTime end,
) {
  var count = 0;
  var current = DateTime(start.year, start.month, start.day);
  final rangeEnd = DateTime(end.year, end.month, end.day);
  while (!current.isAfter(rangeEnd)) {
    final daySchedule = schedule.days[current.weekday.toString()];
    if (daySchedule?.isWorkingDay ?? true) count++;
    current = current.add(const Duration(days: 1));
  }
  return count;
}
