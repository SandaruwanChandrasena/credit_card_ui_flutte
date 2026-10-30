// card_utils_test.dart
// Unit tests for the card rules in card_utils.dart.
// (This was widget_test.dart before. The name is clearer now.)
//
// Run with:  flutter test test/card_utils_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:credit_card_ui_flutte/credit_card/card_utils.dart';

void main() {
  group('getCardType', () {
    test('finds each card type', () {
      expect(getCardType('4111 1111'), 'visa');
      expect(getCardType('3412'), 'amex');
      expect(getCardType('3712'), 'amex');
      expect(getCardType('5112'), 'mastercard');
      expect(getCardType('6011 0000'), 'discover');
      expect(getCardType('9792 0000'), 'troy');
    });

    test('empty or unknown number shows visa (same as React)', () {
      expect(getCardType(''), 'visa');
      expect(getCardType('1234'), 'visa');
    });
  });

  group('formatCardNumber', () {
    test('adds a space after every 4 digits', () {
      expect(formatCardNumber('4111111111111111'), '4111 1111 1111 1111');
    });

    test('stops at 16 digits', () {
      expect(formatCardNumber('41111111111111119999'), '4111 1111 1111 1111');
    });

    test('removes letters and other signs', () {
      expect(formatCardNumber('41ab11-11'), '4111 11');
    });

    test('amex uses 4-6-5 and stops at 15 digits', () {
      expect(formatCardNumber('378282246310005'), '3782 822463 10005');
      expect(formatCardNumber('3782822463100059999'), '3782 822463 10005');
      expect(formatCardNumber('37828'), '3782 8');
    });
  });

  group('CardNameFormatter', () {
    final formatter = CardNameFormatter();

    String run(String text) {
      return formatter
          .formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: text),
          )
          .text;
    }

    test('makes the name upper case', () {
      expect(run('john doe'), 'JOHN DOE');
    });

    test('keeps dot, apostrophe and hyphen, removes numbers', () {
      expect(run("o'neil-smith jr.7"), "O'NEIL-SMITH JR.");
    });

    test('stops at 26 characters', () {
      expect(run('a' * 40).length, maxNameLength);
    });
  });

  group('CVV', () {
    test('Amex has 4 digits, other cards have 3', () {
      expect(cvvLength('3782 822463'), 4);
      expect(cvvLength('4111 1111'), 3);
      expect(cvvLength('5112'), 3);
      expect(cvvLength(''), 3); // no number yet: same as Visa
    });

    String run(int max, String text) {
      return CvvFormatter(() => max)
          .formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: text),
          )
          .text;
    }

    test('keeps digits only and cuts to the length', () {
      expect(run(3, '1a2b3'), '123');
      expect(run(3, '12345'), '123');
      expect(run(4, '12345'), '1234');
    });
  });
}