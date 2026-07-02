// Converts Arabic Unicode (U+0621–U+064A) to Unicode Presentation Forms
// (U+FE70–FEFF) so that the `pdf` package (which does not apply OpenType GSUB)
// can render Arabic text with correct contextual glyph shapes.
//
// Joining rules follow Unicode Standard Arabic character joining types:
//   • Right-joining (non-dual): Alef group, Dal group, Ra group, Waw, special
//   • Dual-joining: all other Arabic letters
//   • Transparent: harakat (U+064B–U+065F), tatweel (U+0640)
//
// Lam-Alef ligatures are applied after individual shaping to avoid having
// the pdf package render two glyphs where the font expects one ligature glyph.

// ignore_for_file: constant_identifier_names

const int _TATWEEL = 0x0640;
// Harakat range (transparent characters — carry no joining weight)
const int _HARAKAT_START = 0x064B;
const int _HARAKAT_END = 0x065F;

// ---------------------------------------------------------------------------
// Joining type table: true = right-joining only; false = dual-joining.
// Characters absent from this map are non-joining (Latin, digits, etc.).
// ---------------------------------------------------------------------------
const Map<int, bool> _rightJoining = {
  0x0621: true, // HAMZA
  0x0622: true, // ALEF WITH MADDA ABOVE
  0x0623: true, // ALEF WITH HAMZA ABOVE
  0x0624: true, // WAW WITH HAMZA ABOVE
  0x0625: true, // ALEF WITH HAMZA BELOW
  0x0626: false, // YEH WITH HAMZA ABOVE  (dual)
  0x0627: true, // ALEF
  0x0628: false, // BA
  0x0629: true, // TEH MARBUTA
  0x062A: false, // TEH
  0x062B: false, // THEH
  0x062C: false, // JEEM
  0x062D: false, // HAH
  0x062E: false, // KHAH
  0x062F: true, // DAL
  0x0630: true, // THAL
  0x0631: true, // RA
  0x0632: true, // ZAIN
  0x0633: false, // SEEN
  0x0634: false, // SHEEN
  0x0635: false, // SAD
  0x0636: false, // DAD
  0x0637: false, // TAH
  0x0638: false, // ZAH
  0x0639: false, // AIN
  0x063A: false, // GHAIN
  0x0641: false, // FA
  0x0642: false, // QAF
  0x0643: false, // KAF
  0x0644: false, // LAM
  0x0645: false, // MEEM
  0x0646: false, // NOON
  0x0647: false, // HEH
  0x0648: true, // WAW
  0x0649: true, // ALEF MAKSURA (right-joining per Unicode)
  0x064A: false, // YEH
};

// ---------------------------------------------------------------------------
// Presentation forms for each Arabic letter: [isolated, final, initial, medial]
// ---------------------------------------------------------------------------
const Map<int, List<int>> _forms = {
  0x0621: [0xFE80, 0xFE80, 0xFE80, 0xFE80], // HAMZA
  0x0622: [0xFE81, 0xFE82, 0xFE81, 0xFE82], // ALEF WITH MADDA
  0x0623: [0xFE83, 0xFE84, 0xFE83, 0xFE84], // ALEF WITH HAMZA ABOVE
  0x0624: [0xFE85, 0xFE86, 0xFE85, 0xFE86], // WAW WITH HAMZA
  0x0625: [0xFE87, 0xFE88, 0xFE87, 0xFE88], // ALEF WITH HAMZA BELOW
  0x0626: [0xFE89, 0xFE8A, 0xFE8B, 0xFE8C], // YEH WITH HAMZA
  0x0627: [0xFE8D, 0xFE8E, 0xFE8D, 0xFE8E], // ALEF
  0x0628: [0xFE8F, 0xFE90, 0xFE91, 0xFE92], // BA
  0x0629: [0xFE93, 0xFE94, 0xFE93, 0xFE94], // TEH MARBUTA
  0x062A: [0xFE95, 0xFE96, 0xFE97, 0xFE98], // TEH
  0x062B: [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // THEH
  0x062C: [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // JEEM
  0x062D: [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // HAH
  0x062E: [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // KHAH
  0x062F: [0xFEA9, 0xFEAA, 0xFEA9, 0xFEAA], // DAL
  0x0630: [0xFEAB, 0xFEAC, 0xFEAB, 0xFEAC], // THAL
  0x0631: [0xFEAD, 0xFEAE, 0xFEAD, 0xFEAE], // RA
  0x0632: [0xFEAF, 0xFEB0, 0xFEAF, 0xFEB0], // ZAIN
  0x0633: [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // SEEN
  0x0634: [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // SHEEN
  0x0635: [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // SAD
  0x0636: [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // DAD
  0x0637: [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // TAH
  0x0638: [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // ZAH
  0x0639: [0xFEC9, 0xFECA, 0xFECB, 0xFECC], // AIN
  0x063A: [0xFECD, 0xFECE, 0xFECF, 0xFED0], // GHAIN
  0x0641: [0xFED1, 0xFED2, 0xFED3, 0xFED4], // FA
  0x0642: [0xFED5, 0xFED6, 0xFED7, 0xFED8], // QAF
  0x0643: [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // KAF
  0x0644: [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // LAM
  0x0645: [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // MEEM
  0x0646: [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // NOON
  0x0647: [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // HEH
  0x0648: [0xFEED, 0xFEEE, 0xFEED, 0xFEEE], // WAW
  0x0649: [0xFEEF, 0xFEF0, 0xFEEF, 0xFEF0], // ALEF MAKSURA
  0x064A: [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // YEH
};

// Lam-Alef ligature map: Lam (0x0644) followed by an Alef variant → ligature
// glyph codes in [isolated, final] forms.
const Map<int, List<int>> _lamAlef = {
  0x0622: [0xFEF5, 0xFEF6], // LAM + ALEF WITH MADDA
  0x0623: [0xFEF7, 0xFEF8], // LAM + ALEF WITH HAMZA ABOVE
  0x0625: [0xFEF9, 0xFEFA], // LAM + ALEF WITH HAMZA BELOW
  0x0627: [0xFEFB, 0xFEFC], // LAM + ALEF
};

bool _isArabic(int cp) => cp >= 0x0621 && cp <= 0x064A;
bool _isTransparent(int cp) =>
    cp == _TATWEEL || (cp >= _HARAKAT_START && cp <= _HARAKAT_END);

/// Whether [cp] can connect to a following letter (i.e. is dual-joining).
bool _connectsRight(int cp) {
  if (_isTransparent(cp)) return false;
  final isRight = _rightJoining[cp];
  if (isRight == null) return false; // non-Arabic → no connection
  return !isRight; // dual-joining = can connect right
}

/// Whether [cp] can connect to a preceding letter.
bool _connectsLeft(int cp) {
  if (_isTransparent(cp)) return false;
  return _rightJoining.containsKey(cp); // any Arabic letter accepts a connection from the left
}

/// Reshapes a single run of Arabic (and mixed) text so that each Arabic letter
/// is replaced by its correct Unicode Presentation Form glyph.
///
/// Non-Arabic characters pass through unchanged. The output string is suitable
/// for rendering with a font that has Presentation Forms (e.g. Cairo) in a
/// layout engine that does not apply OpenType GSUB (e.g. the Dart `pdf` package).
///
/// The text should already be in logical (reading) order; the caller is
/// responsible for RTL paragraph reversal if needed.
String reshapeArabic(String text) {
  if (text.isEmpty) return text;

  final codes = text.runes.toList();
  final n = codes.length;
  final out = List<int>.from(codes);

  for (int i = 0; i < n; i++) {
    final cp = codes[i];
    if (!_isArabic(cp) && !_isTransparent(cp)) continue;
    if (_isTransparent(cp)) continue; // pass through as-is

    final forms = _forms[cp];
    if (forms == null) continue; // unmapped Arabic char, pass through

    // Find the nearest non-transparent predecessor and successor.
    int? prev;
    for (int j = i - 1; j >= 0; j--) {
      if (!_isTransparent(codes[j])) {
        prev = codes[j];
        break;
      }
    }
    int? next;
    for (int j = i + 1; j < n; j++) {
      if (!_isTransparent(codes[j])) {
        next = codes[j];
        break;
      }
    }

    final joinLeft = prev != null && _connectsRight(prev);
    final joinRight = next != null && _connectsLeft(next) && _connectsRight(cp);

    // Determine form: 0=isolated, 1=final, 2=initial, 3=medial
    final int formIndex;
    if (joinLeft && joinRight) {
      formIndex = 3; // medial
    } else if (joinLeft) {
      formIndex = 1; // final
    } else if (joinRight) {
      formIndex = 2; // initial
    } else {
      formIndex = 0; // isolated
    }

    out[i] = forms[formIndex];
  }

  // Second pass: Lam-Alef ligatures.
  // When a Lam presentation form is immediately followed (ignoring transparents)
  // by an Alef variant presentation form, replace both with a single ligature.
  final ligOut = <int>[];
  int i = 0;
  while (i < n) {
    final cp = out[i];

    // Detect any Lam presentation form (initial or medial, i.e. connects right).
    // Lam forms: FEDDiso, FEDEfin, FEDFinit, FEE0med
    final isLamForm = cp == 0xFEDF || cp == 0xFEE0; // initial or medial = connects right
    if (isLamForm) {
      // Scan past transparents to find next glyph.
      int j = i + 1;
      final transparentsBetween = <int>[];
      while (j < n && _isTransparent(codes[j])) {
        transparentsBetween.add(out[j]);
        j++;
      }
      if (j < n) {
        final nextGlyph = out[j];
        // Map Lam-Alef presentation form pairs to ligatures.
        // Alef presentation forms: FE8D/FE8E (plain), FE83/FE84, FE87/FE88, FE81/FE82
        int? alefBase;
        if (nextGlyph == 0xFE8D || nextGlyph == 0xFE8E) alefBase = 0x0627;
        if (nextGlyph == 0xFE83 || nextGlyph == 0xFE84) alefBase = 0x0623;
        if (nextGlyph == 0xFE87 || nextGlyph == 0xFE88) alefBase = 0x0625;
        if (nextGlyph == 0xFE81 || nextGlyph == 0xFE82) alefBase = 0x0622;

        final ligForms = alefBase != null ? _lamAlef[alefBase] : null;
        if (ligForms != null) {
          // Lam in medial position → Lam-Alef final (ligature connects left);
          // Lam in initial position → Lam-Alef isolated (nothing before it).
          final ligGlyph = (cp == 0xFEE0) ? ligForms[1] : ligForms[0];
          ligOut.add(ligGlyph);
          ligOut.addAll(transparentsBetween);
          i = j + 1; // skip both Lam and Alef
          continue;
        }
      }
    }

    ligOut.add(cp);
    i++;
  }

  return String.fromCharCodes(ligOut);
}

/// Returns true if [text] contains any Arabic letter (U+0621–U+064A).
bool containsArabic(String text) =>
    text.runes.any((cp) => cp >= 0x0621 && cp <= 0x064A);
