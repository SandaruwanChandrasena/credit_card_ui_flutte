// card_config.dart
// One place for the things the card UI loads from the internet:
// - fonts (google_fonts)
// - images (card background, chip, logos)
//
// Why this file?
// "flutter test" has no internet. Fonts and images would fail to load,
// and the tests would fail. Tests set CardConfig.offline = true,
// so they use plain fonts and empty boxes instead of images.
// The real app keeps offline = false, so nothing changes there.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CardConfig {
  CardConfig._();

  /// false in the app. Tests set this to true.
  static bool offline = false;

  /// Form text: labels, inputs, button, dropdown.
  /// (Source Sans 3 is the new name of "Source Sans Pro" used in React.)
  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
    return offline ? style : GoogleFonts.sourceSans3(textStyle: style);
  }

  /// Card text: number, name, date.
  static TextStyle code({
    Color? color,
    FontWeight? fontWeight,
    double? height,
    List<Shadow>? shadows,
  }) {
    final style = TextStyle(
      color: color,
      fontWeight: fontWeight,
      height: height,
      shadows: shadows,
    );
    return offline
        ? style.copyWith(fontFamily: 'monospace')
        : GoogleFonts.sourceCodePro(textStyle: style);
  }

  /// A network image. If it fails to load, nothing is shown.
  static Widget image(
    String url, {
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center,
  }) {
    if (offline) return const SizedBox.shrink();
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  /// Download the images early, so they show at once later.
  static void precache(BuildContext context, List<String> urls) {
    if (offline) return;
    for (final url in urls) {
      precacheImage(
        NetworkImage(url),
        context,
        onError: (_, _) {}, // no internet: just skip it
      );
    }
  }
}