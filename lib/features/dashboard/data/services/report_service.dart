import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../attendance/data/models/attendance_model.dart';
import '../../presentation/cubit/dashboard_state.dart';

// ── Palette ──────────────────────────────────────────────────────────────────

const _kNavy = PdfColor.fromInt(0xFF1A3A5C);
const _kGreen = PdfColor.fromInt(0xFF2E7D32);
const _kRed = PdfColor.fromInt(0xFFC62828);
const _kOrange = PdfColor.fromInt(0xFFE65100);
const _kBg = PdfColor.fromInt(0xFFF5F7FA);
const _kBgCard = PdfColor.fromInt(0xFFEEF2F7);
const _kText = PdfColor.fromInt(0xFF1C1C1C);
const _kMuted = PdfColor.fromInt(0xFF6B7280);
const _kDivider = PdfColor.fromInt(0xFFD1D5DB);

// ── Localised labels ─────────────────────────────────────────────────────────

class _L {
  final bool ar;
  const _L(String locale) : ar = locale == 'ar';

  String get appName => ar ? 'تكنو ستاف' : 'Techno Staff';
  String get reportTitle => ar ? 'لقطة العمليات اليومية' : 'Operations Snapshot';
  String get generatedAt => ar ? 'صدر في' : 'Generated';
  String get period => ar ? 'الفترة' : 'Period';
  String get filterToday => ar ? 'اليوم' : 'Today';
  String get filterWeek => ar ? 'هذا الأسبوع' : 'This Week';
  String get filterMonth => ar ? 'هذا الشهر' : 'This Month';

  String get overdueAlert => ar ? 'تنبيه: مهام متأخرة' : 'Overdue Alert';
  String overdueBody(int n) => ar
      ? '$n ${n == 1 ? 'مهمة متأخرة تستدعي الانتباه' : 'مهام متأخرة تستدعي الانتباه'}'
      : '$n open ${n == 1 ? 'task is' : 'tasks are'} past their deadline';

  String get taskSummary => ar ? 'ملخص المهام' : 'Task Summary';
  String get totalTasks => ar ? 'الإجمالي' : 'Total';
  String get completed => ar ? 'مكتمل' : 'Completed';
  String get inProgress => ar ? 'جارية' : 'In Progress';
  String get pending => ar ? 'معلقة' : 'Pending';

  String get deliveryPerf => ar ? 'أداء التسليم' : 'Delivery Performance';
  String get completionRate => ar ? 'معدل الإنجاز' : 'Completion Rate';
  String get onTime => ar ? 'في الوقت' : 'On Time';
  String get late => ar ? 'متأخر' : 'Late';
  String get openOverdue => ar ? 'متأخر مفتوح' : 'Open Overdue';

  String get attendance => ar ? 'الحضور اليوم' : "Today's Attendance";
  String get present => ar ? 'حاضر' : 'Present';
  String get lateLabel => ar ? 'متأخر' : 'Late';
  String get absent => ar ? 'غائب' : 'Absent';

  String get teamInsights => ar ? 'رؤى الفريق' : 'Team Insights';
  String get topPerformer => ar ? 'الأفضل أداءً' : 'Top Performer';
  String get mostActive => ar ? 'الأكثر نشاطاً' : 'Most Active';
  String get tasksCompleted => ar ? 'مهمة مكتملة' : 'tasks completed';
  String get activeTasks => ar ? 'مهام نشطة' : 'active tasks';

  String filterLabel(DashboardFilter f) {
    switch (f) {
      case DashboardFilter.today:
        return filterToday;
      case DashboardFilter.week:
        return filterWeek;
      case DashboardFilter.month:
        return filterMonth;
    }
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

class ReportService {
  static Future<void> exportDashboardReport({
    required Map<String, int> stats,
    required Map<String, dynamic> extraStats,
    required List<AttendanceModel> roster,
    required DashboardFilter filter,
    required String locale,
  }) async {
    final l = _L(locale);
    final isAr = l.ar;
    final dir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

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
    final dateStr = DateFormat('d MMMM yyyy  HH:mm', locale).format(now);

    // ── Metrics ──────────────────────────────────────────────────────────────
    final total = stats['totalTasks'] ?? 0;
    final done = stats['completedTasks'] ?? 0;
    final inProg = stats['inProgressTasks'] ?? 0;
    final pend = stats['pendingTasks'] ?? 0;
    final onTime = stats['completedOnTime'] ?? 0;
    final lateDone = stats['completedLate'] ?? 0;
    final overdue = stats['overdueOpenTasks'] ?? 0;
    final rate = total == 0 ? 0 : ((done / total) * 100).round();

    final presentCount = roster.where((r) =>
        r.status == 'present' || r.status == 'off_day_work').length;
    final lateCount = roster.where((r) => r.status == 'late').length;
    final absentCount = roster.where((r) => r.status == 'absent').length;

    final topPerformerName =
        (extraStats['topPerformer'] ?? '-').toString();
    final topCompleted = (extraStats['topCompleted'] ?? 0) as int;
    final mostActiveName = (extraStats['mostActive'] ?? '-').toString();
    final topActive = (extraStats['topActive'] ?? 0) as int;

    // ── Build page ───────────────────────────────────────────────────────────
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (ctx) => pw.Directionality(
          textDirection: dir,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              _buildHeader(
                logo: logo,
                title: l.reportTitle,
                appName: l.appName,
                periodLabel: '${l.period}: ${l.filterLabel(filter)}',
                generatedLabel: '${l.generatedAt}: $dateStr',
                boldFont: boldFont,
                regularFont: regularFont,
                isAr: isAr,
              ),
              pw.SizedBox(height: 10),
              _divider(),

              // ── Overdue alert ────────────────────────────────────────────
              if (overdue > 0) ...[
                pw.SizedBox(height: 10),
                _overdueAlert(
                  title: l.overdueAlert,
                  body: l.overdueBody(overdue),
                  boldFont: boldFont,
                  regularFont: regularFont,
                ),
              ],

              pw.SizedBox(height: 12),

              // ── Task summary ─────────────────────────────────────────────
              _sectionLabel(l.taskSummary, boldFont),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                _statCell(l.totalTasks, total.toString(), boldFont, regularFont),
                pw.SizedBox(width: 6),
                _statCell(l.completed, done.toString(), boldFont, regularFont,
                    accent: _kGreen),
                pw.SizedBox(width: 6),
                _statCell(l.inProgress, inProg.toString(), boldFont, regularFont,
                    accent: _kOrange),
                pw.SizedBox(width: 6),
                _statCell(l.pending, pend.toString(), boldFont, regularFont),
              ]),

              pw.SizedBox(height: 12),

              // ── Delivery performance ─────────────────────────────────────
              _sectionLabel(l.deliveryPerf, boldFont),
              pw.SizedBox(height: 6),
              _deliveryRow(
                rate: rate,
                onTime: onTime,
                late: lateDone,
                overdue: overdue,
                labels: l,
                boldFont: boldFont,
                regularFont: regularFont,
              ),

              pw.SizedBox(height: 12),

              // ── Attendance today ─────────────────────────────────────────
              _sectionLabel(l.attendance, boldFont),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                _statCell(l.present, presentCount.toString(), boldFont,
                    regularFont, accent: _kGreen),
                pw.SizedBox(width: 6),
                _statCell(l.lateLabel, lateCount.toString(), boldFont,
                    regularFont, accent: _kOrange),
                pw.SizedBox(width: 6),
                _statCell(l.absent, absentCount.toString(), boldFont,
                    regularFont,
                    accent: absentCount > 0 ? _kRed : null),
              ]),

              pw.SizedBox(height: 12),

              // ── Team insights ────────────────────────────────────────────
              _sectionLabel(l.teamInsights, boldFont),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Expanded(
                  child: _insightCell(
                    label: l.topPerformer,
                    name: topPerformerName,
                    detail: '$topCompleted ${l.tasksCompleted}',
                    boldFont: boldFont,
                    regularFont: regularFont,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _insightCell(
                    label: l.mostActive,
                    name: mostActiveName,
                    detail: '$topActive ${l.activeTasks}',
                    boldFont: boldFont,
                    regularFont: regularFont,
                  ),
                ),
              ]),

              pw.Spacer(),
              _divider(),
              pw.SizedBox(height: 4),
              pw.Text(
                '${l.generatedAt}: $dateStr   |   ${l.period}: ${l.filterLabel(filter)}',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 8,
                  color: _kMuted,
                ),
                textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'dashboard_snapshot_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required pw.MemoryImage logo,
    required String title,
    required String appName,
    required String periodLabel,
    required String generatedLabel,
    required pw.Font boldFont,
    required pw.Font regularFont,
    required bool isAr,
  }) {
    final logoWidget = pw.Image(logo, width: 48, height: 48);
    final textBlock = pw.Column(
      crossAxisAlignment:
          isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(appName,
            style: pw.TextStyle(font: boldFont, fontSize: 20, color: _kNavy)),
        pw.SizedBox(height: 2),
        pw.Text(title,
            style: pw.TextStyle(
                font: regularFont, fontSize: 11, color: _kMuted)),
        pw.SizedBox(height: 2),
        pw.Text(periodLabel,
            style: pw.TextStyle(
                font: regularFont, fontSize: 9, color: _kMuted)),
        pw.Text(generatedLabel,
            style: pw.TextStyle(
                font: regularFont, fontSize: 9, color: _kMuted)),
      ],
    );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: isAr
          ? [textBlock, logoWidget]
          : [logoWidget, textBlock],
    );
  }

  // ── Overdue alert box ─────────────────────────────────────────────────────

  static pw.Widget _overdueAlert({
    required String title,
    required String body,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFFF3F3),
        border: pw.Border.all(color: _kRed, width: 1.2),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 6,
            height: 6,
            decoration: const pw.BoxDecoration(
              color: _kRed,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        font: boldFont, fontSize: 10, color: _kRed)),
                pw.SizedBox(height: 2),
                pw.Text(body,
                    style: pw.TextStyle(
                        font: regularFont, fontSize: 9, color: _kText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat cell ─────────────────────────────────────────────────────────────

  static pw.Widget _statCell(
    String label,
    String value,
    pw.Font boldFont,
    pw.Font regularFont, {
    PdfColor? accent,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: _kBgCard,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 18,
                color: accent ?? _kNavy,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 8,
                color: _kMuted,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Delivery row (rate bar + 3 stats) ─────────────────────────────────────

  static pw.Widget _deliveryRow({
    required int rate,
    required int onTime,
    required int late,
    required int overdue,
    required _L labels,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    final barColor = rate >= 80
        ? _kGreen
        : rate >= 60
            ? _kOrange
            : _kRed;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              '${labels.completionRate}: $rate%',
              style: pw.TextStyle(
                  font: boldFont, fontSize: 10, color: _kText),
            ),
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
                child: pw.Container(height: 6, color: barColor),
              ),
            if (rate < 100)
              pw.Flexible(
                flex: 100 - rate,
                child: pw.Container(height: 6, color: _kBgCard),
              ),
          ]),
        ),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          _miniStat(labels.onTime, onTime.toString(), boldFont, regularFont,
              _kGreen),
          pw.SizedBox(width: 6),
          _miniStat(labels.late, late.toString(), boldFont, regularFont,
              late > 0 ? _kOrange : _kMuted),
          pw.SizedBox(width: 6),
          _miniStat(labels.openOverdue, overdue.toString(), boldFont,
              regularFont, overdue > 0 ? _kRed : _kMuted),
        ]),
      ],
    );
  }

  static pw.Widget _miniStat(
    String label,
    String value,
    pw.Font boldFont,
    pw.Font regularFont,
    PdfColor color,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: _kBg,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    font: boldFont, fontSize: 13, color: color)),
            pw.SizedBox(width: 4),
            pw.Text(label,
                style: pw.TextStyle(
                    font: regularFont, fontSize: 8, color: _kMuted)),
          ],
        ),
      ),
    );
  }

  // ── Team insight cell ─────────────────────────────────────────────────────

  static pw.Widget _insightCell({
    required String label,
    required String name,
    required String detail,
    required pw.Font boldFont,
    required pw.Font regularFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _kBgCard,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: regularFont, fontSize: 8, color: _kMuted)),
          pw.SizedBox(height: 3),
          pw.Text(name,
              style: pw.TextStyle(
                  font: boldFont, fontSize: 12, color: _kNavy)),
          pw.SizedBox(height: 1),
          pw.Text(detail,
              style: pw.TextStyle(
                  font: regularFont, fontSize: 8, color: _kMuted)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _sectionLabel(String text, pw.Font boldFont) {
    return pw.Text(
      text,
      style: pw.TextStyle(font: boldFont, fontSize: 10, color: _kNavy),
    );
  }

  static pw.Widget _divider() {
    return pw.Divider(color: _kDivider, thickness: 0.8);
  }
}
