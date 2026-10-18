import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import 'calculator_engine.dart';

enum KeyAction { digit, decimal, operator, equals, clear, sign, percent }

class KeyDef {
  const KeyDef({
    required this.label,
    required this.semantics,
    required this.action,
    this.digit,
    this.op,
    this.accent = false,
    this.flex = 1,
  });

  final String label;
  final String semantics;
  final KeyAction action;
  final String? digit;
  final CalcOp? op;
  final bool accent;
  final int flex;
}

/// Row 1: AC, +/-, %, divide. Row 5: 0 across two cells, decimal, equals
/// (SPEC 8.2).
const List<List<KeyDef>> keypadRows = <List<KeyDef>>[
  <KeyDef>[
    KeyDef(label: 'AC', semantics: 'clear', action: KeyAction.clear),
    KeyDef(label: '+/-', semantics: 'sign', action: KeyAction.sign),
    KeyDef(label: '%', semantics: 'percent', action: KeyAction.percent),
    KeyDef(
      label: '÷',
      semantics: 'divide',
      action: KeyAction.operator,
      op: CalcOp.divide,
    ),
  ],
  <KeyDef>[
    KeyDef(label: '7', semantics: '7', action: KeyAction.digit, digit: '7'),
    KeyDef(label: '8', semantics: '8', action: KeyAction.digit, digit: '8'),
    KeyDef(label: '9', semantics: '9', action: KeyAction.digit, digit: '9'),
    KeyDef(
      label: '×',
      semantics: 'multiply',
      action: KeyAction.operator,
      op: CalcOp.multiply,
    ),
  ],
  <KeyDef>[
    KeyDef(label: '4', semantics: '4', action: KeyAction.digit, digit: '4'),
    KeyDef(label: '5', semantics: '5', action: KeyAction.digit, digit: '5'),
    KeyDef(label: '6', semantics: '6', action: KeyAction.digit, digit: '6'),
    KeyDef(
      label: '-',
      semantics: 'minus',
      action: KeyAction.operator,
      op: CalcOp.subtract,
    ),
  ],
  <KeyDef>[
    KeyDef(label: '1', semantics: '1', action: KeyAction.digit, digit: '1'),
    KeyDef(label: '2', semantics: '2', action: KeyAction.digit, digit: '2'),
    KeyDef(label: '3', semantics: '3', action: KeyAction.digit, digit: '3'),
    KeyDef(
      label: '+',
      semantics: 'plus',
      action: KeyAction.operator,
      op: CalcOp.add,
    ),
  ],
  <KeyDef>[
    KeyDef(
      label: '0',
      semantics: 'zero',
      action: KeyAction.digit,
      digit: '0',
      flex: 2,
    ),
    KeyDef(label: '.', semantics: 'decimal', action: KeyAction.decimal),
    KeyDef(
      label: '=',
      semantics: 'equals',
      action: KeyAction.equals,
      accent: true,
    ),
  ],
];

class KeyButton extends StatefulWidget {
  const KeyButton({
    super.key,
    required this.def,
    required this.onPressed,
    this.onLongPress,
  });

  final KeyDef def;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _pressed = false;
  bool _focused = false;
  bool _moved = false;
  bool _holdFired = false;
  Timer? _holdTimer;
  Offset? _downPosition;

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _handleDown(PointerDownEvent event) {
    setState(() => _pressed = true);
    _moved = false;
    _holdFired = false;
    _downPosition = event.position;
    if (widget.onLongPress != null) {
      _holdTimer = Timer(Timing.pinLongPress, () {
        _holdFired = true;
        HapticFeedback.mediumImpact();
        widget.onLongPress!();
      });
    }
  }

  void _handleMove(PointerMoveEvent event) {
    final start = _downPosition;
    if (start == null) {
      return;
    }
    if ((event.position - start).distance >
        Timing.pinLongPressMoveTolerance) {
      _moved = true;
      _cancelHold();
    }
  }

  void _handleUp(PointerUpEvent event) {
    _cancelHold();
    _downPosition = null;
    setState(() => _pressed = false);
    if (_holdFired || _moved) {
      return;
    }
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  void _activate() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final background = _pressed
        ? Palette.keyPressed
        : (def.accent ? Palette.oxide : Palette.keySurface);
    final foreground = def.accent ? Palette.paper : Palette.ink;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) {
        if (value != _focused) {
          setState(() => _focused = value);
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: def.semantics,
        onTap: _activate,
        child: Listener(
          onPointerDown: _handleDown,
          onPointerMove: _handleMove,
          onPointerUp: _handleUp,
          onPointerCancel: (_) {
            _cancelHold();
            setState(() => _pressed = false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: def.accent ? Palette.oxide : Palette.keyOutline,
                width: _focused ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              def.label,
              style: AppTypography.key.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.onKey,
    this.onAcLongPress,
  });

  final void Function(KeyDef def) onKey;
  final VoidCallback? onAcLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < keypadRows.length; row++) ...[
          if (row > 0) const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                for (var column = 0;
                    column < keypadRows[row].length;
                    column++) ...[
                  if (column > 0) const SizedBox(width: 4),
                  Expanded(
                    flex: keypadRows[row][column].flex,
                    child: KeyButton(
                      def: keypadRows[row][column],
                      onPressed: () => onKey(keypadRows[row][column]),
                      onLongPress: keypadRows[row][column].action ==
                              KeyAction.clear
                          ? onAcLongPress
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
