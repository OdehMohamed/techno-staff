/// Converts an agorot integer (1 agorot = ₪0.01) to a natural-language
/// currency string. Supports English and Arabic.
///
/// arabic: false → "Five Hundred New Shekels"
/// arabic: true  → "خمسمائة شيكل جديد"
///
/// Valid range: 1–99,999,999 agorot (₪0.01–₪999,999.99).
String amountInWords(int agorot, {required bool arabic}) {
  if (agorot <= 0) return arabic ? 'صفر' : 'Zero';
  final ils = agorot ~/ 100;
  final cents = agorot % 100;
  return arabic ? _arAmount(ils, cents) : _enAmount(ils, cents);
}

// ─── English ──────────────────────────────────────────────────────────────────

const _enOnes = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];
const _enTens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
  'Sixty', 'Seventy', 'Eighty', 'Ninety',
];

String _enBelow100(int n) {
  if (n < 20) return _enOnes[n];
  final o = n % 10;
  return '${_enTens[n ~/ 10]}${o > 0 ? '-${_enOnes[o]}' : ''}';
}

String _enBelow1000(int n) {
  if (n < 100) return _enBelow100(n);
  final rem = n % 100;
  return '${_enOnes[n ~/ 100]} Hundred'
      '${rem > 0 ? ' and ${_enBelow100(rem)}' : ''}';
}

String _enIls(int ils) {
  if (ils < 1000) return _enBelow1000(ils);
  final th = ils ~/ 1000;
  final rem = ils % 1000;
  return '${_enBelow1000(th)} Thousand'
      '${rem > 0 ? ' ${_enBelow1000(rem)}' : ''}';
}

String _enAmount(int ils, int cents) {
  final parts = <String>[];
  if (ils > 0) {
    parts.add('${_enIls(ils)} New ${ils == 1 ? 'Shekel' : 'Shekels'}');
  }
  if (cents > 0) {
    parts.add('${_enBelow100(cents)} Agorot');
  }
  return parts.join(' and ');
}

// ─── Arabic ───────────────────────────────────────────────────────────────────
//
// Grammatical notes (Modern Standard Arabic):
//   • شيكل (shekel) is masculine. Numbers 3–9 before a masculine noun take the
//     feminine (tā-marbūṭa) form: ثلاثة, أربعة, … خمسة, etc.
//   • For amounts 1–2: special noun forms (singular / dual).
//   • For amounts 3–10: feminine unit + plural noun (شواكل).
//   • For amounts ≥ 11 with a non-round remainder: accusative singular tamyīz
//     (شيكلاً جديداً).
//   • For round hundreds / thousands (n % 100 == 0): genitive singular
//     (شيكل جديد).

// Ones 0–10. Indices 3–10 are the feminine forms used with masculine nouns.
const _arOnes = [
  '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة',
  'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة',
];

// Teens 10–19 (index 0 = 10).
const _arTeens = [
  'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر',
  'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
];

// Tens 20–90.
const _arTens = [
  '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون',
  'ستون', 'سبعون', 'ثمانون', 'تسعون',
];

// Hundreds 100–900. Index 0 unused.
const _arHundreds = [
  '', 'مئة', 'مئتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة',
  'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة',
];

String _arBelow100(int n) {
  if (n == 0) return '';
  if (n <= 10) return _arOnes[n];
  if (n < 20) return _arTeens[n - 10];
  final o = n % 10;
  final t = _arTens[n ~/ 10];
  return o == 0 ? t : '${_arOnes[o]} و$t';
}

String _arBelow1000(int n) {
  if (n == 0) return '';
  if (n < 100) return _arBelow100(n);
  final h = _arHundreds[n ~/ 100];
  final rem = n % 100;
  return rem == 0 ? h : '$h و${_arBelow100(rem)}';
}

// Builds the thousands part (1–999 thousands).
String _arThousands(int th) {
  if (th == 1) return 'ألف';
  if (th == 2) return 'ألفان';
  if (th <= 10) return '${_arOnes[th]} آلاف';
  if (th >= 100) return '${_arBelow1000(th)} ألف';
  return '${_arBelow100(th)} ألفاً';
}

String _arIls(int ils) {
  if (ils < 1000) return _arBelow1000(ils);
  final th = ils ~/ 1000;
  final rem = ils % 1000;
  final tPart = _arThousands(th);
  return rem == 0 ? tPart : '$tPart و${_arBelow1000(rem)}';
}

String _arAmount(int ils, int cents) {
  final parts = <String>[];

  if (ils > 0) {
    if (ils == 1) {
      parts.add('شيكل جديد واحد');
    } else if (ils == 2) {
      parts.add('شيكلان جديدان');
    } else if (ils <= 10) {
      parts.add('${_arOnes[ils]} شواكل جديدة');
    } else if (ils % 100 == 0) {
      // Round hundreds / thousands → genitive singular
      parts.add('${_arIls(ils)} شيكل جديد');
    } else {
      // Compound or non-round → accusative singular tamyīz
      parts.add('${_arIls(ils)} شيكلاً جديداً');
    }
  }

  if (cents > 0) {
    if (cents == 1) {
      parts.add('أغورة واحدة');
    } else if (cents == 2) {
      parts.add('أغورتان');
    } else if (cents <= 10) {
      parts.add('${_arOnes[cents]} أغورات');
    } else {
      parts.add('${_arBelow100(cents)} أغورة');
    }
  }

  return parts.join(' و');
}
