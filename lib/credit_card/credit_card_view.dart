import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'card_config.dart';
import 'card_utils.dart';
import 'enter_animation.dart';

/// Which part of the card has the white "focus box" on it.
enum CardFocusTarget { number, name, date }

/// The card picture (front + back), with all the animations:
/// - 3D flip when [isFlipped] changes (for CVV)
/// - focus box that moves to number / name / date
/// - digits slide up, name letters slide in, date slides up
/// - CVV stars pop in
/// - logo fades in when the card type changes
///
/// The card is drawn at 430 x 270 (same as React) and then scaled
/// to fit the space with FittedBox. So all sizes stay the same on every phone.
class CreditCardView extends StatefulWidget {
  const CreditCardView({
    super.key,
    required this.cardNumber,
    required this.cardName,
    required this.cardMonth,
    required this.cardYear,
    required this.cardCvv,
    required this.isFlipped,
    this.focusTarget,
    this.onTapNumber,
    this.onTapName,
  });

  final String cardNumber;
  final String cardName;
  final String cardMonth;
  final String cardYear;
  final String cardCvv;
  final bool isFlipped;
  final CardFocusTarget? focusTarget;
  final VoidCallback? onTapNumber;
  final VoidCallback? onTapName;

  /// Design size (same as the React CSS).
  static const double designWidth = 430;
  static const double designHeight = 270;

  @override
  State<CreditCardView> createState() => _CreditCardViewState();
}

class _CreditCardViewState extends State<CreditCardView>
    with SingleTickerProviderStateMixin {
  // FLIP: 0.9s, same curve as the CSS transition.
  late final AnimationController _flipController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.isFlipped ? 1 : 0,
  );
  late final Animation<double> _flip = CurvedAnimation(
    parent: _flipController,
    curve: smoothCurve,
    reverseCurve: smoothCurve.flipped,
  );

  // FOCUS BOX: keys to find where each part is on the card.
  final _frontKey = GlobalKey();
  final _numberKey = GlobalKey();
  final _nameKey = GlobalKey();
  final _dateKey = GlobalKey();
  Rect? _focusRect;

  static const _textShadow = [
    Shadow(offset: Offset(7, 6), blurRadius: 10, color: Color(0xCC0E2A5A)),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.focusTarget != null) _scheduleMeasure();
  }

  @override
  void didUpdateWidget(CreditCardView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isFlipped != widget.isFlipped) {
      widget.isFlipped ? _flipController.forward() : _flipController.reverse();
    }

    if (widget.focusTarget == null) {
      // No focus: the box goes back to full card size and fades out (same as CSS).
      _focusRect = null;
    } else {
      // Measure after this frame. The number width can change (Amex), so we
      // measure on every update while something has focus.
      _scheduleMeasure();
    }
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = switch (widget.focusTarget) {
        CardFocusTarget.number => _numberKey,
        CardFocusTarget.name => _nameKey,
        CardFocusTarget.date => _dateKey,
        null => null,
      };
      if (key == null) return;
      final rect = _rectOf(key);
      if (rect != null && rect != _focusRect) {
        setState(() => _focusRect = rect);
      }
    });
  }

  /// Position of a part, inside the front side of the card.
  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final front = _frontKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || front == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero, ancestor: front);
    return offset & box.size;
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  String get _cardType => getCardType(widget.cardNumber);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: CreditCardView.designWidth,
        height: CreditCardView.designHeight,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = _flip.value * math.pi;
            final showFront = angle <= math.pi / 2;

            final transform = Matrix4.identity()
              ..setEntry(3, 2, 1 / 1200) // perspective: 1200px
              ..rotateY(angle);

            // Both sides stay in the tree all the time. We only hide one.
            // So the digits do not play their animation again after a flip.
            return Transform(
              alignment: Alignment.center,
              transform: transform,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Visibility(
                    visible: showFront,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: _side(_buildFront()),
                  ),
                  Visibility(
                    visible: !showFront,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    // Turn the back one more half turn, so its text is not mirrored.
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _side(_buildBack()),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Shadow + rounded corners, for both sides.
  Widget _side(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 25),
            blurRadius: 50,
            color: Color(0x470F172A),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  /// Background picture + dark gradient on top.
  Widget _cover() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF1C1D27),
        foregroundDecoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x2E0C1225), Color(0x730C1225)],
          ),
        ),
        child: CardConfig.image(
          cardBackgroundUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// LOGO FADE: new key when the type changes, so the animation plays again.
  Widget _logo() {
    final type = _cardType;
    return SizedBox(
      width: 100,
      height: 45,
      child: EnterAnimation(
        key: ValueKey(type),
        from: const Offset(0, -8),
        scaleFrom: 0.85,
        duration: const Duration(milliseconds: 400),
        child: CardConfig.image(
          logoUrl(type),
          fit: BoxFit.contain,
          alignment: Alignment.topRight,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- FRONT

  Widget _buildFront() {
    final fullCard = const Offset(0, 0) &
        const Size(CreditCardView.designWidth, CreditCardView.designHeight);
    final rect = _focusRect ?? fullCard;
    final focusVisible = widget.focusTarget != null && _focusRect != null;

    return Stack(
      key: _frontKey,
      children: [
        _cover(),

        // FOCUS BOX: moves and resizes to the focused part.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: smoothCurve,
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              curve: smoothCurve,
              opacity: focusVisible ? 1 : 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x8CFFFFFF), width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Card text
        DefaultTextStyle(
          style: CardConfig.code(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            height: 1,
            shadows: _textShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chip + logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 45,
                        child: CardConfig.image(
                          chipUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.topLeft,
                        ),
                      ),
                      const Spacer(),
                      _logo(),
                    ],
                  ),
                ),
                // (React uses 40 here. 36 keeps a little free space, so nothing overflows.)
                const SizedBox(height: 36),

                // Card number
                GestureDetector(
                  onTap: widget.onTapNumber,
                  child: Container(
                    key: _numberKey,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildNumberSlots(),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Name + date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildName()),
                    _buildDate(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNumberSlots() {
    final isAmex = _cardType == 'amex';
    final mask = isAmex ? amexCardMask : otherCardMask;
    final number = widget.cardNumber;

    return List.generate(mask.length, (index) {
      final maskChar = mask[index];
      final isSpace = maskChar.trim().isEmpty;
      final current = index < number.length ? number[index] : null;

      // Same rule as React: hide the middle digits with "*".
      final shouldMask = isAmex
          ? index > 4 && index < 14 && current != null && !isSpace
          : index > 4 && index < 15 && current != null && !isSpace;
      final shown = shouldMask ? '*' : (current ?? maskChar);

      return AnimatedContainer(
        key: ValueKey('slot-$index'),
        duration: const Duration(milliseconds: 250),
        width: isSpace ? 30 : 16,
        alignment: Alignment.center,
        // ANIMATION: new key when the shown text changes, so it slides up again.
        child: EnterAnimation(
          key: ValueKey('$index-$shown'),
          from: const Offset(0, 12),
          child: Text(
            shown,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: const TextStyle(fontSize: 27, letterSpacing: 1),
          ),
        ),
      );
    });
  }

  Widget _buildName() {
    final name = widget.cardName.replaceAll(RegExp(r'\s\s+'), ' ');

    final List<Widget> letters;
    if (name.isEmpty) {
      letters = const [
        EnterAnimation(
          key: ValueKey('placeholder'),
          from: Offset(10, 0),
          child: Text('FULL NAME'),
        ),
      ];
    } else {
      // ANIMATION: one widget per letter, so each new letter slides in.
      letters = List.generate(name.length, (index) {
        final letter = name[index];
        return EnterAnimation(
          key: ValueKey('$index-$letter'),
          from: const Offset(10, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 8),
            child: Text(letter),
          ),
        );
      });
    }

    return GestureDetector(
      onTap: widget.onTapName,
      child: Container(
        key: _nameKey,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Opacity(
              opacity: 0.8,
              child: Text(
                'Card Holder',
                style: TextStyle(fontSize: 13, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            // Long names shrink to fit, instead of going off the card.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 18),
                child: Row(mainAxisSize: MainAxisSize.min, children: letters),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDate() {
    final month = widget.cardMonth.isEmpty ? 'MM' : widget.cardMonth;
    final year = widget.cardYear.isEmpty ? 'YY' : widget.cardYear.substring(2, 4);

    Widget part(String text) => SizedBox(
          width: 22,
          // ANIMATION: new key when the value changes, so it slides up.
          child: EnterAnimation(
            key: ValueKey(text),
            from: const Offset(0, 12),
            child: Text(text, softWrap: false),
          ),
        );

    return Container(
      key: _dateKey,
      width: 80,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Opacity(
            opacity: 0.8,
            child: Text(
              'Expires',
              softWrap: false,
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          // Shrinks a little if the font is wide, so it never overflows.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [part(month), const Text('/'), part(year)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- BACK

  Widget _buildBack() {
    return Stack(
      children: [
        _cover(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            // Black magnetic band
            Container(height: 50, color: const Color(0xCC000013)),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      'CVV',
                      style: CardConfig.sans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // White CVV band
                  Container(
                    height: 45,
                    padding: const EdgeInsets.only(right: 10),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          offset: Offset(0, 10),
                          blurRadius: 20,
                          spreadRadius: -7,
                          color: Color(0x59203875),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.cardCvv.length, (index) {
                        // ANIMATION: each star pops in.
                        return EnterAnimation(
                          key: ValueKey('cvv-$index'),
                          scaleFrom: 0.4,
                          duration: const Duration(milliseconds: 250),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Text(
                              '*',
                              style: CardConfig.sans(
                                fontSize: 18,
                                color: const Color(0xFF1A3B5D),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Opacity(opacity: 0.8, child: _logo()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}