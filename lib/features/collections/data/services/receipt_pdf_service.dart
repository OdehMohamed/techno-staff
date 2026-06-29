import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/payment_model.dart';
import 'amount_in_words.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kNavy = PdfColor.fromInt(0xFF1A3A5C);
const _kText = PdfColor.fromInt(0xFF1C1C1C);
const _kMuted = PdfColor.fromInt(0xFF6B7280);
const _kDivider = PdfColor.fromInt(0xFFD1D5DB);
const _kBg = PdfColor.fromInt(0xFFF5F7FA);

// ─── Localised labels ─────────────────────────────────────────────────────────

class _L {
  final bool ar;
  const _L(String locale) : ar = locale == 'ar';

  String get appName => 'Techno Staff';
  String get receiptTitle => ar ? 'إيصال استلام / Receipt' : 'RECEIPT / إيصال';
  String get receiptNo => ar ? 'رقم الإيصال' : 'Receipt No.';
  String get receivedFrom => ar ? 'استُلم من' : 'Received from';
  String get contact => ar ? 'الهاتف' : 'Contact';
  String get amount => ar ? 'المبلغ' : 'Amount';
  String get inWords => ar ? 'بالكلمات' : 'In words';
  String get inArabic => ar ? 'بالإنجليزية' : 'In Arabic';
  String get paymentMethod => ar ? 'طريقة الدفع' : 'Payment method';
  String get receivedBy => ar ? 'استُلم بواسطة' : 'Received by';
  String get remainingBalance => ar ? 'الرصيد المتبقي' : 'Remaining balance';
  String get date => ar ? 'التاريخ' : 'Date';
  String get disclaimer => ar
      ? 'هذا الإيصال إثبات للدفع المستلم — الإيصال الرسمي يُقدَّم بشكل منفصل'
      : 'This receipt is a record of payment received — Official receipt to be provided separately';
  String get page => ar ? 'صفحة' : 'Page';

  String methodLabel(String method) {
    switch (method) {
      case 'cash':
        return ar ? 'نقداً' : 'Cash';
      case 'check':
        return ar ? 'شيك' : 'Check';
      case 'bank_transfer':
        return ar ? 'تحويل بنكي' : 'Bank Transfer';
      default:
        return method;
    }
  }
}

bool _containsArabic(String text) =>
    text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

pw.TextDirection _dir(String text) =>
    _containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

// ─── Public API ───────────────────────────────────────────────────────────────

/// Generates a PDF receipt and returns the saved [File].
/// Caller is responsible for sharing: `Printing.sharePdf(bytes: await file.readAsBytes(), ...)`.
Future<File> generateReceiptPdf({
  required PaymentModel payment,
  required String customerPhone,
  required int remainingBalanceAfterPayment,
  required String locale,
}) async {
  final l = _L(locale);
  final isAr = l.ar;
  final dir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final align = isAr ? pw.TextAlign.right : pw.TextAlign.left;

  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List(),
  );

  final dateLabel = DateFormat('d MMMM yyyy  HH:mm', locale)
      .format(payment.collectedAt.toLocal());
  final amountFormatted =
      '₪${(payment.amount / 100).toStringAsFixed(2)}';
  final balanceFormatted =
      '₪${(remainingBalanceAfterPayment / 100).toStringAsFixed(2)}';

  final wordsEn = amountInWords(payment.amount, arabic: false);
  final wordsAr = amountInWords(payment.amount, arabic: true);
  final firstWords = isAr ? wordsAr : wordsEn;
  final secondWords = isAr ? wordsEn : wordsAr;
  final firstLabel = l.inWords;
  final secondLabel = l.inArabic;

  pw.TextStyle base({bool bold = false, double size = 10, PdfColor? color}) =>
      pw.TextStyle(
        font: bold ? boldFont : regularFont,
        fontSize: size,
        color: color ?? _kText,
      );

  pw.Widget labelValue(String label, String value, {bool rtlValue = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: base(color: _kMuted)),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              textDirection: _dir(value),
              style: base(bold: true),
            ),
          ),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      textDirection: dir,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: isAr
            ? pw.CrossAxisAlignment.end
            : pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 48, height: 48),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(l.appName,
                      style: base(bold: true, size: 14, color: _kNavy)),
                  pw.Text(l.receiptTitle,
                      style: base(size: 11, color: _kNavy)),
                ],
              ),
            ],
          ),
          pw.Divider(color: _kDivider, height: 16),

          // Receipt meta
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: _kBg),
            child: pw.Column(
              crossAxisAlignment: isAr
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                labelValue(l.receiptNo, payment.receiptNumber),
                labelValue(l.date, dateLabel),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // Party details
          labelValue(
            l.receivedFrom,
            payment.customerName,
            rtlValue: _containsArabic(payment.customerName),
          ),
          if (customerPhone.isNotEmpty)
            labelValue(l.contact, customerPhone),
          pw.Divider(color: _kDivider, height: 16),

          // Amount
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(l.amount, style: base(color: _kMuted)),
                pw.Text(amountFormatted,
                    style: base(bold: true, size: 14, color: _kNavy)),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '$firstLabel: $firstWords',
              textAlign: align,
              textDirection: dir,
              style: base(size: 9, color: _kMuted),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(
              '$secondLabel: $secondWords',
              textAlign: isAr ? pw.TextAlign.left : pw.TextAlign.right,
              textDirection: isAr
                  ? pw.TextDirection.ltr
                  : pw.TextDirection.rtl,
              style: base(size: 9, color: _kMuted),
            ),
          ),
          pw.Divider(color: _kDivider, height: 10),

          // Payment details
          labelValue(
              l.paymentMethod, l.methodLabel(payment.paymentMethod)),
          labelValue(
            l.receivedBy,
            payment.collectorName,
            rtlValue: _containsArabic(payment.collectorName),
          ),
          labelValue(l.remainingBalance, balanceFormatted),
          pw.Divider(color: _kDivider, height: 16),

          // Disclaimer
          pw.Center(
            child: pw.Text(
              l.disclaimer,
              textAlign: pw.TextAlign.center,
              textDirection: dir,
              style: base(size: 8, color: _kMuted),
            ),
          ),

          // Page number
          pw.Spacer(),
          pw.Center(
            child: pw.Text(
              '${l.page} 1',
              style: base(size: 8, color: _kMuted),
            ),
          ),
        ],
      ),
    ),
  );

  final dir2 = await getTemporaryDirectory();
  final file = File(
      '${dir2.path}/receipt_${payment.receiptNumber.replaceAll('-', '_')}.pdf');
  await file.writeAsBytes(await doc.save());
  return file;
}
