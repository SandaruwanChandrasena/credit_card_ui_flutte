// card_utils.dart
// Shared helpers for the credit card UI:
// - image links (same as the React project)
// - card masks and limits
// - card type check
// - text formatters for the inputs (same rules as the React onChange code)

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------
// IMAGE LINKS
// ---------------------------------------------------------------
const String cardImagesUrl =
    'https://raw.githubusercontent.com/muhammederdem/credit-card-form/master/src/assets/images';

const String cardBackgroundUrl =
    'https://images.unsplash.com/photo-1557683316-973673baf926?auto=format&fit=crop&w=860&q=80';

const String chipUrl = '$cardImagesUrl/chip.png';

const List<String> cardTypes = ['visa', 'amex', 'mastercard', 'discover', 'troy'];

String logoUrl(String type) => '$cardImagesUrl/$type.png';

// ---------------------------------------------------------------
// MASKS AND LIMITS
// ---------------------------------------------------------------
const String amexCardMask = '#### ###### #####';
const String otherCardMask = '#### #### #### ####';

/// Real cards allow about 26 characters for the name (ISO/IEC 7813).
const int maxNameLength = 26;

/// Page load curve. Same as CSS cubic-bezier(0.16, 1, 0.3, 1).
const Curve enterCurve = Cubic(0.16, 1, 0.3, 1);

// ---------------------------------------------------------------
// CARD TYPE
// ---------------------------------------------------------------
String getCardType(String cardNumber) {
  final clean = cardNumber.replaceAll(RegExp(r'\s'), '');
  if (RegExp(r'^4').hasMatch(clean)) return 'visa';
  if (RegExp(r'^(34|37)').hasMatch(clean)) return 'amex';
  if (RegExp(r'^5[1-5]').hasMatch(clean)) return 'mastercard';
  if (RegExp(r'^6011').hasMatch(clean)) return 'discover';
  if (RegExp(r'^9792').hasMatch(clean)) return 'troy';
  return 'visa';
}

// ---------------------------------------------------------------
// CARD NUMBER FORMAT
// Amex:  #### ###### #####   (15 digits)
// Other: #### #### #### #### (16 digits)
// ---------------------------------------------------------------
String formatCardNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final isAmex = RegExp(r'^(34|37)').hasMatch(digits);
  final maxLength = isAmex ? 15 : 16;
  final trimmed =
      digits.length > maxLength ? digits.substring(0, maxLength) : digits;

  if (isAmex) {
    final parts = <String>[];
    if (trimmed.isNotEmpty) parts.add(_slice(trimmed, 0, 4));
    if (trimmed.length > 4) parts.add(_slice(trimmed, 4, 10));
    if (trimmed.length > 10) parts.add(_slice(trimmed, 10, 15));
    return parts.join(' ');
  }

  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(trimmed[i]);
  }
  return buffer.toString();
}

/// Like JavaScript slice: never goes past the end of the text.
String _slice(String text, int start, int end) {
  return text.substring(start, end > text.length ? text.length : end);
}

// ---------------------------------------------------------------
// CVV LENGTH
// American Express has a 4-digit code (on the front of the card).
// All other cards have a 3-digit code (on the back).
// ---------------------------------------------------------------
int cvvLength(String cardNumber) {
  return getCardType(cardNumber) == 'amex' ? 4 : 3;
}

// ---------------------------------------------------------------
// INPUT FORMATTERS (run on every key press)
// ---------------------------------------------------------------

/// Adds the spaces and limits the length of the card number.
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatCardNumber(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Keeps only letters, spaces, dot, apostrophe and hyphen.
/// Makes it upper case. Max 26 characters.
class CardNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var cleaned = newValue.text.replaceAll(RegExp(r"[^a-zA-Z\s.'-]"), '');
    if (cleaned.length > maxNameLength) {
      cleaned = cleaned.substring(0, maxNameLength);
    }
    cleaned = cleaned.toUpperCase();
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

/// Keeps only digits, and cuts the CVV to the right length.
/// [maxLength] is a function, so the limit can change when the
/// card type changes (3 digits, or 4 for Amex).
class CvvFormatter extends TextInputFormatter {
  CvvFormatter(this.maxLength);

  final int Function() maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final max = maxLength();
    if (digits.length > max) digits = digits.substring(0, max);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}