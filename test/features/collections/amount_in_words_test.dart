import 'package:flutter_test/flutter_test.dart';
import 'package:techno_staff/features/collections/data/services/amount_in_words.dart';

void main() {
  group('amountInWords — English', () {
    test('₪1 (100 agorot)', () {
      expect(amountInWords(100, arabic: false), 'One New Shekel');
    });
    test('₪2', () {
      expect(amountInWords(200, arabic: false), 'Two New Shekels');
    });
    test('₪5', () {
      expect(amountInWords(500, arabic: false), 'Five New Shekels');
    });
    test('₪10', () {
      expect(amountInWords(1000, arabic: false), 'Ten New Shekels');
    });
    test('₪11', () {
      expect(amountInWords(1100, arabic: false), 'Eleven New Shekels');
    });
    test('₪21', () {
      expect(amountInWords(2100, arabic: false), 'Twenty-One New Shekels');
    });
    test('₪50', () {
      expect(amountInWords(5000, arabic: false), 'Fifty New Shekels');
    });
    test('₪100', () {
      expect(amountInWords(10000, arabic: false), 'One Hundred New Shekels');
    });
    test('₪115', () {
      expect(amountInWords(11500, arabic: false),
          'One Hundred and Fifteen New Shekels');
    });
    test('₪500', () {
      expect(amountInWords(50000, arabic: false),
          'Five Hundred New Shekels');
    });
    test('₪1000', () {
      expect(amountInWords(100000, arabic: false),
          'One Thousand New Shekels');
    });
    test('₪1500', () {
      expect(amountInWords(150000, arabic: false),
          'One Thousand Five Hundred New Shekels');
    });
    test('₪5000', () {
      expect(amountInWords(500000, arabic: false),
          'Five Thousand New Shekels');
    });
    test('₪10000', () {
      expect(amountInWords(1000000, arabic: false),
          'Ten Thousand New Shekels');
    });
    test('₪10250', () {
      expect(amountInWords(1025000, arabic: false),
          'Ten Thousand Two Hundred and Fifty New Shekels');
    });
    test('agorot only — 50 agorot (₪0.50)', () {
      expect(amountInWords(50, arabic: false), 'Fifty Agorot');
    });
    test('ILS + agorot — ₪1.50', () {
      expect(amountInWords(150, arabic: false),
          'One New Shekel and Fifty Agorot');
    });
  });

  group('amountInWords — Arabic', () {
    test('₪1', () {
      expect(amountInWords(100, arabic: true), 'شيكل جديد واحد');
    });
    test('₪2', () {
      expect(amountInWords(200, arabic: true), 'شيكلان جديدان');
    });
    test('₪3', () {
      expect(amountInWords(300, arabic: true), 'ثلاثة شواكل جديدة');
    });
    test('₪5', () {
      expect(amountInWords(500, arabic: true), 'خمسة شواكل جديدة');
    });
    test('₪10', () {
      expect(amountInWords(1000, arabic: true), 'عشرة شواكل جديدة');
    });
    test('₪11', () {
      expect(amountInWords(1100, arabic: true), 'أحد عشر شيكلاً جديداً');
    });
    test('₪50', () {
      expect(amountInWords(5000, arabic: true), 'خمسون شيكلاً جديداً');
    });
    test('₪100', () {
      expect(amountInWords(10000, arabic: true), 'مئة شيكل جديد');
    });
    test('₪115', () {
      expect(amountInWords(11500, arabic: true), 'مئة وخمسة عشر شيكلاً جديداً');
    });
    test('₪200', () {
      expect(amountInWords(20000, arabic: true), 'مئتان شيكل جديد');
    });
    test('₪500', () {
      expect(amountInWords(50000, arabic: true), 'خمسمائة شيكل جديد');
    });
    test('₪1000', () {
      expect(amountInWords(100000, arabic: true), 'ألف شيكل جديد');
    });
    test('₪1500', () {
      expect(amountInWords(150000, arabic: true),
          'ألف وخمسمائة شيكل جديد');
    });
    test('₪1523', () {
      expect(amountInWords(152300, arabic: true),
          'ألف وخمسمائة وثلاثة وعشرون شيكلاً جديداً');
    });
    test('₪2000', () {
      expect(amountInWords(200000, arabic: true), 'ألفان شيكل جديد');
    });
    test('₪5000', () {
      expect(amountInWords(500000, arabic: true), 'خمسة آلاف شيكل جديد');
    });
    test('₪10000', () {
      expect(amountInWords(1000000, arabic: true), 'عشرة آلاف شيكل جديد');
    });
    test('₪25000', () {
      expect(amountInWords(2500000, arabic: true),
          'خمسة وعشرون ألفاً شيكل جديد');
    });
    test('agorot only — 50 agorot (₪0.50)', () {
      expect(amountInWords(50, arabic: true), 'خمسون أغورة');
    });
    test('ILS + agorot — ₪1.50', () {
      expect(amountInWords(150, arabic: true), 'شيكل جديد واحد وخمسون أغورة');
    });
  });
}
