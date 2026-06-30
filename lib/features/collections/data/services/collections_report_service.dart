import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/debt_model.dart';
import '../models/handover_model.dart';
import '../models/payment_model.dart';
import 'arabic_reshaper.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kNavy = PdfColor.fromInt(0xFF1A3A5C);
const _kText = PdfColor.fromInt(0xFF1C1C1C);
const _kMuted = PdfColor.fromInt(0xFF6B7280);
const _kDivider = PdfColor.fromInt(0xFFD1D5DB);
const _kBg = PdfColor.fromInt(0xFFF5F7FA);
const _kHeaderRow = PdfColor.fromInt(0xFFDDE3EE);
const _kRed = PdfColor.fromInt(0xFFC62828);

// ─── Localised labels ─────────────────────────────────────────────────────────

class _L {
  final bool ar;
  const _L(String locale) : ar = locale == 'ar';

  String get appName => 'Techno Staff';
  String get handoverTitle => ar ? 'تقرير تسوية التسليم' : 'Handover Reconciliation';
  String get agingTitle => ar ? 'تقرير تقادم الديون' : 'Debt Aging Report';
  String get collector => ar ? 'المحصّل' : 'Collector';
  String get date => ar ? 'التاريخ' : 'Date';
  String get verifiedBy => ar ? 'التحقق بواسطة' : 'Verified By';
  String get claimedAmount => ar ? 'المبلغ المطالب به' : 'Claimed Amount';
  String get actualAmount => ar ? 'المبلغ الفعلي' : 'Actual Amount';
  String get discrepancy => ar ? 'الفرق' : 'Discrepancy';
  String get status => ar ? 'الحالة' : 'Status';
  String get receiptNo => ar ? 'رقم الإيصال' : 'Receipt No.';
  String get customer => ar ? 'العميل' : 'Customer';
  String get amount => ar ? 'المبلغ' : 'Amount';
  String get method => ar ? 'الطريقة' : 'Method';
  String get collectedDate => ar ? 'تاريخ التحصيل' : 'Collected Date';
  String get total => ar ? 'الإجمالي' : 'Total';
  String get generatedAt => ar ? 'صدر في' : 'Generated';
  String get page => ar ? 'صفحة' : 'Page';
  String get of => ar ? 'من' : 'of';
  // Aging report
  String get customerCol => ar ? 'العميل' : 'Customer';
  String get collectorCol => ar ? 'المحصّل' : 'Collector';
  String get originalAmount => ar ? 'المبلغ الأصلي' : 'Original Amount';
  String get remaining => ar ? 'الرصيد المتبقي' : 'Remaining Balance';
  String get daysOverdue => ar ? 'أيام التأخر' : 'Days Overdue';
  String get subtotal => ar ? 'المجموع الفرعي' : 'Subtotal';
  String get grandTotal => ar ? 'الإجمالي الكلي' : 'Grand Total';
  String bucketLabel(String b) {
    switch (b) {
      case 'current':
        return ar ? 'جارية' : 'Current';
      case '1-30':
        return ar ? '1–30 يوم' : '1–30 Days';
      case '31-60':
        return ar ? '31–60 يوم' : '31–60 Days';
      case '61-90':
        return ar ? '61–90 يوم' : '61–90 Days';
      case '90+':
        return ar ? '90+ يوم' : '90+ Days';
      default:
        return b;
    }
  }

  String methodLabel(String m) {
    switch (m) {
      case 'cash':
        return ar ? 'نقداً' : 'Cash';
      case 'check':
        return ar ? 'شيك' : 'Check';
      case 'bank_transfer':
        return ar ? 'تحويل بنكي' : 'Bank Transfer';
      default:
        return m;
    }
  }

  String statusLabel(String s) {
    switch (s) {
      case 'pending':
        return ar ? 'معلق' : 'Pending';
      case 'verified':
        return ar ? 'موثّق' : 'Verified';
      default:
        return s;
    }
  }
}

bool _containsArabic(String text) =>
    text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

String _pdfText(String text) => reshapeArabic(text);

// ─── Shared helpers ───────────────────────────────────────────────────────────

Future<pw.Font> _regular() async =>
    pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));

Future<pw.Font> _bold() async =>
    pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));

Future<pw.MemoryImage> _logo() async => pw.MemoryImage(
      (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
    );

// Cairo font does not include the ₪ glyph (U+20AA). Use ILS in PDFs.
String _fmt(int agorot) => 'ILS ${(agorot / 100).toStringAsFixed(2)}';
String _fmtDate(DateTime dt, String locale) =>
    DateFormat('d MMM yyyy', locale).format(dt.toLocal());

pw.Widget _cell(
  String text,
  pw.Font font, {
  bool bold = false,
  pw.Font? boldFont,
  PdfColor? color,
  pw.TextAlign? align,
  bool rtl = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      _pdfText(text),
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: align,
      style: pw.TextStyle(
        font: bold ? boldFont ?? font : font,
        fontSize: 8,
        color: color ?? _kText,
      ),
    ),
  );
}

// ─── Handover Reconciliation PDF ─────────────────────────────────────────────

Future<File> generateHandoverReconciliationPdf({
  required HandoverModel handover,
  required List<PaymentModel> payments,
  required String locale,
}) async {
  final l = _L(locale);
  final isAr = l.ar;
  final dir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  final regular = await _regular();
  final bold = await _bold();
  final logo = await _logo();

  final now = DateTime.now();
  final generated = DateFormat('d MMMM yyyy  HH:mm', locale).format(now);

  pw.TextStyle base({bool isBold = false, double size = 9, PdfColor? color}) =>
      pw.TextStyle(
        font: isBold ? bold : regular,
        fontSize: size,
        color: color ?? _kText,
      );

  pw.Widget labelRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_pdfText(label), style: base(color: _kMuted)),
            pw.Text(
              _pdfText(value),
              textDirection: _containsArabic(value)
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              style: base(isBold: true),
            ),
          ],
        ),
      );

  // Sort payments by collectedAt
  final sorted = [...payments]
    ..sort((a, b) => a.collectedAt.compareTo(b.collectedAt));

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: dir,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Column(
        crossAxisAlignment: isAr
            ? pw.CrossAxisAlignment.end
            : pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 40, height: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(_pdfText(l.appName),
                      style: base(isBold: true, size: 13, color: _kNavy)),
                  pw.Text(_pdfText(l.handoverTitle),
                      style: base(size: 10, color: _kNavy)),
                ],
              ),
            ],
          ),
          pw.Divider(color: _kDivider, height: 12),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(generated, style: base(size: 7, color: _kMuted)),
          pw.Text(
            '${l.page} ${context.pageNumber} ${l.of} ${context.pagesCount}',
            style: base(size: 7, color: _kMuted),
          ),
        ],
      ),
      build: (context) => [
        // Summary card
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(color: _kBg),
          child: pw.Column(
            crossAxisAlignment: isAr
                ? pw.CrossAxisAlignment.end
                : pw.CrossAxisAlignment.start,
            children: [
              labelRow(l.collector, handover.collectorName),
              labelRow(l.date, _fmtDate(handover.initiatedAt, locale)),
              if (handover.verifiedAt != null)
                labelRow(l.verifiedBy, handover.receivedByName ?? '—'),
              labelRow(l.claimedAmount, _fmt(handover.claimedAmount)),
              if (handover.actualAmount != null)
                labelRow(l.actualAmount, _fmt(handover.actualAmount!)),
              if (handover.hasDiscrepancy &&
                  handover.discrepancyAmount != null)
                labelRow(l.discrepancy,
                    _fmt(handover.discrepancyAmount!.abs())),
              labelRow(l.status, l.statusLabel(handover.status)),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // Payments table header
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.8),
          },
          border: pw.TableBorder.all(color: _kDivider, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _kHeaderRow),
              children: [
                _cell(l.receiptNo, bold, bold: true, boldFont: bold),
                _cell(l.customer, bold, bold: true, boldFont: bold,
                    rtl: isAr),
                _cell(l.amount, bold,
                    bold: true,
                    boldFont: bold,
                    align: pw.TextAlign.right),
                _cell(l.method, bold, bold: true, boldFont: bold),
                _cell(l.collectedDate, bold, bold: true, boldFont: bold),
              ],
            ),
            ...sorted.map(
              (p) => pw.TableRow(
                children: [
                  _cell(p.receiptNumber.isEmpty ? '—' : p.receiptNumber,
                      regular),
                  _cell(
                    p.customerName,
                    regular,
                    rtl: _containsArabic(p.customerName),
                  ),
                  _cell(_fmt(p.amount), regular,
                      align: pw.TextAlign.right),
                  _cell(l.methodLabel(p.paymentMethod), regular),
                  _cell(_fmtDate(p.collectedAt, locale), regular),
                ],
              ),
            ),
            // Total row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _kHeaderRow),
              children: [
                pw.SizedBox(),
                _cell(l.total, bold, bold: true, boldFont: bold),
                _cell(
                  _fmt(sorted.fold<int>(0, (s, p) => s + p.amount)),
                  bold,
                  bold: true,
                  boldFont: bold,
                  align: pw.TextAlign.right,
                ),
                pw.SizedBox(),
                pw.SizedBox(),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  final tmpDir = await getTemporaryDirectory();
  final file = File(
      '${tmpDir.path}/handover_${handover.id.substring(0, 8)}.pdf');
  await file.writeAsBytes(await doc.save());
  return file;
}

// ─── Aging Report PDF ─────────────────────────────────────────────────────────

const _bucketOrder = ['90+', '61-90', '31-60', '1-30', 'current'];

Future<File> generateAgingReportPdf({
  required List<DebtModel> debts,
  required String locale,
}) async {
  final l = _L(locale);
  final isAr = l.ar;
  final dir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  final regular = await _regular();
  final bold = await _bold();
  final logo = await _logo();

  final now = DateTime.now();
  final generated = DateFormat('d MMMM yyyy  HH:mm', locale).format(now);
  final reportDate = DateFormat('d MMMM yyyy', locale).format(now);

  pw.TextStyle base({bool isBold = false, double size = 8.5, PdfColor? color}) =>
      pw.TextStyle(
        font: isBold ? bold : regular,
        fontSize: size,
        color: color ?? _kText,
      );

  // Group debts by agingBucket, sort within each bucket by remainingBalance desc
  final grouped = <String, List<DebtModel>>{};
  for (final bucket in _bucketOrder) {
    final items = debts
        .where((d) => d.agingBucket == bucket)
        .toList()
      ..sort((a, b) => b.remainingBalance.compareTo(a.remainingBalance));
    if (items.isNotEmpty) grouped[bucket] = items;
  }

  pw.Widget headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          _pdfText(text),
          textDirection: _containsArabic(text)
              ? pw.TextDirection.rtl
              : pw.TextDirection.ltr,
          style: base(isBold: true, color: _kNavy),
        ),
      );

  pw.Widget dataCell(String text, {bool rtl = false, pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          _pdfText(text),
          textDirection:
              rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          textAlign: align,
          style: base(),
        ),
      );

  List<pw.Widget> buildBucketSection(
      String bucket, List<DebtModel> items) {
    final subtotalRemaining =
        items.fold<int>(0, (s, d) => s + d.remainingBalance);
    return [
      pw.Container(
        color: _kHeaderRow,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
          _pdfText(l.bucketLabel(bucket)),
          style: base(isBold: true, size: 9, color: _kNavy),
        ),
      ),
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(2.5),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(1.8),
          3: const pw.FlexColumnWidth(1.8),
          4: const pw.FlexColumnWidth(1),
        },
        border: pw.TableBorder.all(color: _kDivider, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kBg),
            children: [
              headerCell(l.customerCol),
              headerCell(l.collectorCol),
              headerCell(l.originalAmount),
              headerCell(l.remaining),
              headerCell(l.daysOverdue),
            ],
          ),
          ...items.map(
            (d) => pw.TableRow(
              children: [
                dataCell(d.customerName,
                    rtl: _containsArabic(d.customerName)),
                dataCell(d.assignedCollectorName,
                    rtl: _containsArabic(d.assignedCollectorName)),
                dataCell(_fmt(d.originalAmount),
                    align: pw.TextAlign.right),
                dataCell(_fmt(d.remainingBalance),
                    align: pw.TextAlign.right),
                dataCell(d.daysPastDue.toString(),
                    align: pw.TextAlign.center),
              ],
            ),
          ),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kHeaderRow),
            children: [
              pw.SizedBox(),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(_pdfText(l.subtotal),
                    style: base(isBold: true, color: _kRed)),
              ),
              pw.SizedBox(),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  _fmt(subtotalRemaining),
                  textAlign: pw.TextAlign.right,
                  style: base(isBold: true, color: _kRed),
                ),
              ),
              pw.SizedBox(),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
    ];
  }

  final grandTotal =
      debts.fold<int>(0, (s, d) => s + d.remainingBalance);

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: dir,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(
        crossAxisAlignment: isAr
            ? pw.CrossAxisAlignment.end
            : pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 40, height: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(_pdfText(l.appName),
                      style: base(isBold: true, size: 13, color: _kNavy)),
                  pw.Text(_pdfText(l.agingTitle),
                      style: base(size: 10, color: _kNavy)),
                  pw.Text(reportDate, style: base(size: 8, color: _kMuted)),
                ],
              ),
            ],
          ),
          pw.Divider(color: _kDivider, height: 12),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(generated, style: base(size: 7, color: _kMuted)),
          pw.Text(
            '${l.page} ${context.pageNumber} ${l.of} ${context.pagesCount}',
            style: base(size: 7, color: _kMuted),
          ),
        ],
      ),
      build: (_) => [
        ...grouped.entries.expand(
          (e) => buildBucketSection(e.key, e.value),
        ),
        // Grand total
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: _kHeaderRow),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(_pdfText(l.grandTotal),
                  style: base(isBold: true, size: 10, color: _kNavy)),
              pw.Text(_fmt(grandTotal),
                  style: base(isBold: true, size: 10, color: _kRed)),
            ],
          ),
        ),
      ],
    ),
  );

  final tmpDir = await getTemporaryDirectory();
  final tag =
      DateFormat('yyyyMMdd').format(now);
  final file = File('${tmpDir.path}/aging_report_$tag.pdf');
  await file.writeAsBytes(await doc.save());
  return file;
}
