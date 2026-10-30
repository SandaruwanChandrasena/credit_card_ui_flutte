// custom_select.dart
// The month / year picker. Same as the React CustomSelect:
// - the menu opens ABOVE the box
// - open: fade + slide up (0.2s)
// - close: fade + slide down (0.18s), then the menu is removed
// - the arrow turns 180 degrees
// - a tap outside closes it

import 'package:flutter/material.dart';
import 'card_config.dart';

class SelectOption {
  const SelectOption(this.value, this.label);
  final String value;
  final String label;
}

class CustomSelect extends StatefulWidget {
  const CustomSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.placeholder,
    required this.onChanged,
    this.onOpen,
    this.onClose,
  });

  final String label;
  final String value; // "" means nothing picked yet
  final List<SelectOption> options;
  final String placeholder;
  final ValueChanged<String> onChanged;

  /// Called when the menu opens (the card moves its focus box to the date).
  final VoidCallback? onOpen;

  /// Called when the menu closes (the card hides its focus box).
  final VoidCallback? onClose;

  @override
  State<CustomSelect> createState() => _CustomSelectState();
}

class _CustomSelectState extends State<CustomSelect>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  // Taps inside the box OR inside the menu are "inside".
  final Object _tapGroup = Object();

  // FIX: these are made in initState, not "late" on first use.
  // Before, if a menu was never opened, the controller was made for the
  // first time inside dispose(). That is not allowed and threw an error.
  late final AnimationController _menuController;
  late final Animation<double> _menuAnim;

  bool _open = false;
  double _width = 0;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _menuAnim = CurvedAnimation(parent: _menuController, curve: Curves.ease);
  }

  void _openMenu() {
    if (_open) return;
    setState(() => _open = true);
    _portal.show();
    _menuController.forward(from: 0);
    widget.onOpen?.call();
  }

  void _closeMenu() {
    if (!_open) return;
    setState(() => _open = false);
    widget.onClose?.call();

    // DROPDOWN CLOSE: play the close animation, THEN remove the menu.
    // (If the user opens it again before the end, this never runs.)
    _menuController.reverse().whenComplete(() {
      if (mounted && !_open) _portal.hide();
    });
  }

  void _toggle() => _open ? _closeMenu() : _openMenu();

  void _select(String value) {
    widget.onChanged(value);
    _closeMenu();
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value.isNotEmpty;
    String? selectedLabel;
    for (final option in widget.options) {
      if (option.value == widget.value) selectedLabel = option.label;
    }

    return TapRegion(
      groupId: _tapGroup,
      onTapOutside: (_) => _closeMenu(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: CardConfig.sans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _portal,
              overlayChildBuilder: _buildMenu,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Save the width, so the menu is as wide as the box.
                  _width = constraints.maxWidth;
                  return _buildTrigger(hasValue ? (selectedLabel ?? widget.value) : null);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The box you tap.
  Widget _buildTrigger(String? shownValue) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _open ? Colors.white : const Color(0xEBFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _open ? const Color(0xFF2563EB) : const Color(0xFFD7E2F0),
          ),
          boxShadow: _open
              ? const [
                  BoxShadow(color: Color(0x1F2563EB), spreadRadius: 4),
                ]
              : const [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                shownValue ?? widget.placeholder,
                overflow: TextOverflow.ellipsis,
                style: CardConfig.sans(
                  fontSize: 17,
                  color: shownValue == null
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1A2B4B),
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.ease,
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF3B4D6B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The list that opens above the box.
  Widget _buildMenu(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        // The menu's bottom-left sits 6px above the box's top-left.
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -6),
        child: TapRegion(
          groupId: _tapGroup,
          child: AnimatedBuilder(
            animation: _menuAnim,
            builder: (context, child) {
              final t = _menuAnim.value;
              // CSS: from opacity 0, translateY(8px) scale(0.98)
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: Transform.scale(
                    scale: 0.98 + 0.02 * t,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              );
            },
            child: SizedBox(
              width: _width,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: const Color(0xFAFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDBE7F3)),
                  boxShadow: const [
                    BoxShadow(
                      offset: Offset(0, 18),
                      blurRadius: 40,
                      color: Color(0x240F172A),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: widget.options.map(_buildOption).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(SelectOption option) {
    final selected = option.value == widget.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => _select(option.value),
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFFEEF4FF),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFDBEAFE), Color(0xFFEFF6FF)],
                  )
                : null,
          ),
          child: Text(
            option.label,
            style: CardConfig.sans(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF1E3354),
            ),
          ),
        ),
      ),
    );
  }
}