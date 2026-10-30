// credit_card_form_test.dart
// Widget tests for the payment page. They "use" the app like a person:
// type in the boxes, tap the CVV box, pick a month and year,
// and check what the card shows.
//
// Run with:  flutter test test/credit_card_form_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:credit_card_ui_flutte/credit_card/card_config.dart';
import 'package:credit_card_ui_flutte/credit_card/credit_card_form.dart';

/// Opens the page on a phone-sized screen (360 x 800)
/// and waits until the page load animation ends.
Future<void> openPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: CreditCardFormPage()));
  await tester.pumpAndSettle();
}

// The 3 text boxes, in page order.
final numberField = find.byType(TextField).at(0);
final nameField = find.byType(TextField).at(1);
final cvvField = find.byType(TextField).at(2);

/// The text inside a text box.
String textOf(WidgetTester tester, Finder field) {
  return tester.widget<TextField>(field).controller!.text;
}

void main() {
  // No internet in tests: use plain fonts and skip the images.
  setUp(() => CardConfig.offline = true);

  testWidgets('page opens with an empty card', (tester) async {
    await openPage(tester);

    expect(find.text('Card Number'), findsOneWidget);
    expect(find.text('Card Holder'), findsNWidgets(2)); // form label + card
    expect(find.text('Pay Now'), findsOneWidget);

    // Card placeholders
    expect(find.text('#'), findsNWidgets(16));
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('MM'), findsOneWidget);
    expect(find.text('YY'), findsOneWidget);
  });

  testWidgets('card number is formatted and the middle is hidden',
      (tester) async {
    await openPage(tester);

    await tester.enterText(numberField, '4111111111111111');
    await tester.pumpAndSettle();

    expect(textOf(tester, numberField), '4111 1111 1111 1111');
    expect(find.text('#'), findsNothing); // all slots are filled
    expect(find.text('*'), findsNWidgets(8)); // 8 middle digits hidden
  });

  testWidgets('amex number uses the 4-6-5 format', (tester) async {
    await openPage(tester);

    await tester.enterText(numberField, '378282246310005');
    await tester.pumpAndSettle();

    expect(textOf(tester, numberField), '3782 822463 10005');
    expect(find.text('#'), findsNothing);
    expect(find.text('*'), findsNWidgets(8));
  });

  testWidgets('name is upper case and shows on the card', (tester) async {
    await openPage(tester);

    await tester.enterText(nameField, 'john doe7');
    await tester.pumpAndSettle();

    expect(textOf(tester, nameField), 'JOHN DOE'); // number removed
    expect(find.text('FULL NAME'), findsNothing);
    expect(find.text('J'), findsOneWidget); // one widget per letter
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('CVV box flips the card, leaving it flips back',
      (tester) async {
    await openPage(tester);

    /// true if the card side that holds [inside] is showing.
    bool sideVisible(Finder inside) {
      final side = find.ancestor(of: inside, matching: find.byType(Visibility));
      return tester.widget<Visibility>(side.first).visible;
    }

    // At the start the front shows.
    expect(sideVisible(find.text('FULL NAME')), isTrue);

    // Type in the CVV box (this also gives it focus).
    await tester.enterText(cvvField, '12a3');
    await tester.pumpAndSettle();

    expect(textOf(tester, cvvField), '123'); // digits only
    expect(find.text('*'), findsNWidgets(3)); // 3 stars on the back
    expect(sideVisible(find.text('FULL NAME')), isFalse); // front hidden
    expect(sideVisible(find.text('*').first), isTrue); // back shows

    // Leave the CVV box: the card turns back.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(sideVisible(find.text('FULL NAME')), isTrue);
  });

  testWidgets('picking a month shows it on the card', (tester) async {
    await openPage(tester);

    // Open the month menu
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget); // in the menu

    // Pick January
    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();

    expect(find.text('MM'), findsNothing);
    expect(find.text('01'), findsNWidgets(2)); // picker box + card
  });

  testWidgets('this year hides past months and clears a past month',
      (tester) async {
    final now = DateTime.now();
    if (now.month == 1) {
      // In January no month is in the past, so there is nothing to test.
      return;
    }

    await openPage(tester);

    // 1. Pick January.
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();
    expect(find.text('MM'), findsNothing);

    // 2. Pick this year. January is now in the past, so it is cleared.
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${now.year}'));
    await tester.pumpAndSettle();

    expect(find.text('MM'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);

    // 3. The month menu now starts at this month.
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    final thisMonth = now.month.toString().padLeft(2, '0');
    expect(find.text('01'), findsNothing);
    expect(find.text(thisMonth), findsOneWidget);

    // Close the menu by picking this month.
    await tester.tap(find.text(thisMonth));
    await tester.pumpAndSettle();
  });
}