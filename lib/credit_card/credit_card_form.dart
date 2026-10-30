// credit_card_form.dart
// The full payment page. Same as the React CreditCardForm:
// - card on top, white form slides down from under it
// - inputs fade in one by one
// - typing updates the card live
// - focus box moves to number / name / date
// - card flips when the CVV box has focus

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'card_config.dart';
import 'card_utils.dart';
import 'credit_card_view.dart';
import 'custom_select.dart';

class CreditCardFormPage extends StatefulWidget {
  const CreditCardFormPage({super.key});

  @override
  State<CreditCardFormPage> createState() => _CreditCardFormPageState();
}

class _CreditCardFormPageState extends State<CreditCardFormPage>
    with SingleTickerProviderStateMixin {
  // Text boxes
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _cvvController = TextEditingController();

  final _numberFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _cvvFocus = FocusNode();

  String _cardMonth = '';
  String _cardYear = '';
  bool _isFlipped = false;
  CardFocusTarget? _focusTarget;

  // True while the month or year menu is open.
  bool _dateOpen = false;

  // Waits 200ms before hiding the focus box (same as React).
  Timer? _blurTimer;

  bool _logosLoaded = false;

  // PAGE LOAD: one controller for the whole entry animation (2.1s).
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );

  @override
  void initState() {
    super.initState();

    // Rebuild the card on every key press.
    _numberController.addListener(_onNumberChanged);
    _nameController.addListener(_refresh);
    _cvvController.addListener(_refresh);

    _numberFocus.addListener(_onFocusChange);
    _nameFocus.addListener(_onFocusChange);
    _cvvFocus.addListener(() {
      setState(() => _isFlipped = _cvvFocus.hasFocus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // LOGO FADE: download all logos at the start, so a change shows at once.
    if (!_logosLoaded) {
      _logosLoaded = true;
      CardConfig.precache(context, [
        for (final type in cardTypes) logoUrl(type),
        chipUrl,
        cardBackgroundUrl,
      ]);

      // Phone setting "remove animations": skip the entry animation.
      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  void _refresh() => setState(() {});

  /// CVV LENGTH: if the card type changes (for example Amex -> Visa),
  /// the CVV may now be too long. Cut it to the new length.
  void _onNumberChanged() {
    final max = cvvLength(_numberController.text);
    final cvv = _cvvController.text;
    if (cvv.length > max) {
      _cvvController.text = cvv.substring(0, max);
    }
    setState(() {});
  }

  // ------------------------------------------------------------ FOCUS BOX

  /// Which card part should have the box right now.
  CardFocusTarget? _currentTarget() {
    if (_numberFocus.hasFocus) return CardFocusTarget.number;
    if (_nameFocus.hasFocus) return CardFocusTarget.name;
    if (_dateOpen) return CardFocusTarget.date;
    return null;
  }

  void _onFocusChange() {
    if (_numberFocus.hasFocus || _nameFocus.hasFocus) {
      _showBox();
    } else {
      _hideBoxLater();
    }
  }

  void _showBox() {
    _blurTimer?.cancel();
    setState(() => _focusTarget = _currentTarget());
  }

  /// Wait 200ms, then check again. If the user moved to another
  /// field in that time, the box just moves there instead of hiding.
  void _hideBoxLater() {
    _blurTimer?.cancel();
    _blurTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _focusTarget = _currentTarget());
    });
  }

  void _onDateOpen() {
    _dateOpen = true;
    // Leave the text box (and hide the keyboard), like a click on a
    // React select. Then the focus box moves to the date.
    FocusManager.instance.primaryFocus?.unfocus();
    _showBox();
  }

  void _onDateClose() {
    _dateOpen = false;
    _hideBoxLater();
  }

  // ------------------------------------------------------------ DATE LISTS

  int get _minYear => DateTime.now().year;

  int get _minMonth {
    if (int.tryParse(_cardYear) == _minYear) return DateTime.now().month;
    return 1;
  }

  List<SelectOption> get _monthOptions {
    return [
      for (var n = _minMonth; n <= 12; n++)
        SelectOption(n.toString().padLeft(2, '0'), n.toString().padLeft(2, '0')),
    ];
  }

  List<SelectOption> get _yearOptions {
    return [
      for (var i = 0; i < 12; i++)
        SelectOption('${_minYear + i}', '${_minYear + i}'),
    ];
  }

  void _onYearChanged(String year) {
    setState(() {
      _cardYear = year;
      // A month in the past is not allowed for this year, so clear it.
      if (_cardMonth.isNotEmpty && int.parse(_cardMonth) < _minMonth) {
        _cardMonth = '';
      }
    });
  }

  void _onPay() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Card ${_numberController.text} - ${_nameController.text}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _blurTimer?.cancel();
    _enter.dispose();
    _numberController.dispose();
    _nameController.dispose();
    _cvvController.dispose();
    _numberFocus.dispose();
    _nameFocus.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ PAGE LOAD ANIMATION

  /// A part of the 2.1s timeline, from [startMs] to [endMs].
  Animation<double> _part(int startMs, int endMs) {
    return CurvedAnimation(
      parent: _enter,
      curve: Interval(startMs / 2100, endMs / 2100, curve: enterCurve),
    );
  }

  // Made once (not on every build).
  late final Animation<double> _cardAnim = _part(0, 900);
  late final Animation<double> _formMove = _part(400, 1800);
  late final Animation<double> _formFade = _part(400, 820); // CSS: fully visible at 30%
  late final List<Animation<double>> _itemAnims = [
    for (var i = 0; i < 4; i++) _part(1000 + 120 * i, 1700 + 120 * i),
  ];

  /// 1. Card: fades in and grows a little (0 - 0.9s).
  Widget _cardEnter(Widget child) {
    final a = _cardAnim;
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - a.value)),
          child: Transform.scale(scale: 0.94 + 0.06 * a.value, child: child),
        ),
      ),
    );
  }

  /// 2. White form: slides down from under the card (0.4s - 1.8s).
  Widget _formEnter(Widget child) {
    return AnimatedBuilder(
      animation: _enter,
      child: child,
      builder: (context, child) => Opacity(
        opacity: _formFade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -140 * (1 - _formMove.value)),
          child: child,
        ),
      ),
    );
  }

  /// 3. Inputs and button: fade up one after another (from 1.0s, 0.12s apart).
  Widget _itemEnter(int index, Widget child) {
    final a = _itemAnims[index];
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - a.value)),
          child: child,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ BUILD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF4FF), Color(0xFFDBEAFE), Color(0xFFF8FBFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 570),
                child: LayoutBuilder(builder: _buildLayout),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;
    final narrow = maxWidth < 480;

    // Card size: 430 x 270 on big screens, 90% width on phones.
    final cardWidth = narrow ? maxWidth * 0.9 : 430.0;
    final cardHeight = cardWidth * 270 / 430;

    // How much the card covers the top of the white form.
    final overlap = cardHeight * 0.48;

    return Stack(
      children: [
        // White form (behind the card)
        Padding(
          padding: EdgeInsets.only(top: cardHeight - overlap),
          child: _formEnter(_buildPanel(narrow, topSpace: overlap + 60)),
        ),

        // Card (on top)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _cardEnter(
              SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: CreditCardView(
                  cardNumber: _numberController.text,
                  cardName: _nameController.text,
                  cardMonth: _cardMonth,
                  cardYear: _cardYear,
                  cardCvv: _cvvController.text,
                  isFlipped: _isFlipped,
                  focusTarget: _focusTarget,
                  onTapNumber: () => _numberFocus.requestFocus(),
                  onTapName: () => _nameFocus.requestFocus(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(bool narrow, {required double topSpace}) {
    final side = narrow ? 20.0 : 35.0;

    return Container(
      padding: EdgeInsets.fromLTRB(side, topSpace, side, side),
      decoration: BoxDecoration(
        color: const Color(0xC7FFFFFF),
        borderRadius: BorderRadius.circular(narrow ? 18 : 24),
        border: Border.all(color: const Color(0x8CFFFFFF)),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 20),
            blurRadius: 50,
            color: Color(0x261F2937),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _itemEnter(
            0,
            _CardInput(
              label: 'Card Number',
              hint: '1234 5678 9012 3456',
              controller: _numberController,
              focusNode: _numberFocus,
              keyboardType: TextInputType.number,
              formatters: [CardNumberFormatter()],
            ),
          ),
          const SizedBox(height: 20),
          _itemEnter(
            1,
            _CardInput(
              label: 'Card Holder',
              hint: 'JOHN DOE',
              controller: _nameController,
              focusNode: _nameFocus,
              keyboardType: TextInputType.name,
              capitalization: TextCapitalization.characters,
              formatters: [CardNameFormatter()],
            ),
          ),
          const SizedBox(height: 20),
          _itemEnter(2, _buildDateAndCvv(narrow)),
          const SizedBox(height: 24),
          _itemEnter(3, _PayButton(onPressed: _onPay)),
        ],
      ),
    );
  }

  Widget _buildDateAndCvv(bool narrow) {
    final date = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CustomSelect(
            label: 'Expiration Date',
            value: _cardMonth,
            options: _monthOptions,
            placeholder: 'Month',
            onChanged: (m) => setState(() => _cardMonth = m),
            onOpen: _onDateOpen,
            onClose: _onDateClose,
          ),
        ),
        SizedBox(width: narrow ? 12 : 15),
        Expanded(
          child: CustomSelect(
            label: ' ',
            value: _cardYear,
            options: _yearOptions,
            placeholder: 'Year',
            onChanged: _onYearChanged,
            onOpen: _onDateOpen,
            onClose: _onDateClose,
          ),
        ),
      ],
    );

    final cvv = _CardInput(
      label: 'CVV',
      // Amex: 4 digits. Other cards: 3 digits.
      hint: cvvLength(_numberController.text) == 4 ? '1234' : '123',
      controller: _cvvController,
      focusNode: _cvvFocus,
      keyboardType: TextInputType.number,
      formatters: [CvvFormatter(() => cvvLength(_numberController.text))],
    );

    // Small screens: CVV goes under the date.
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [date, const SizedBox(height: 20), cvv],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: date),
        const SizedBox(width: 35),
        SizedBox(width: 150, child: cvv),
      ],
    );
  }
}

// ------------------------------------------------------------ INPUT BOX

/// Label + text box with the blue glow on focus.
class _CardInput extends StatelessWidget {
  const _CardInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.formatters,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<TextInputFormatter> formatters;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: CardConfig.sans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: focusNode,
          builder: (context, child) {
            final focused = focusNode.hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              height: 54,
              decoration: BoxDecoration(
                color: focused ? Colors.white : const Color(0xEBFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD7E2F0),
                ),
                boxShadow: focused
                    ? const [BoxShadow(color: Color(0x1F2563EB), spreadRadius: 4)]
                    : const [],
              ),
              alignment: Alignment.centerLeft,
              child: child,
            );
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            inputFormatters: formatters,
            autocorrect: false,
            enableSuggestions: false,
            style: CardConfig.sans(
              fontSize: 17,
              color: const Color(0xFF1A2B4B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: CardConfig.sans(
                fontSize: 17,
                color: const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ PAY BUTTON

/// Blue gradient button. It sinks a little when you press it.
class _PayButton extends StatefulWidget {
  const _PayButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            boxShadow: const [
              BoxShadow(
                offset: Offset(0, 15),
                blurRadius: 30,
                color: Color(0x402563EB),
              ),
            ],
          ),
          child: Text(
            'Pay Now',
            style: CardConfig.sans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}