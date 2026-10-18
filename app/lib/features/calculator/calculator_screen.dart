import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../services/secure_store.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../incident/audio_recorder.dart';
import '../incident/incident.dart';
import '../setup/pin_gate_screen.dart';
import '../trigger/pin_hasher.dart';
import '../trigger/trigger_controller.dart';
import '../trigger/trigger_detector.dart';
import 'calculator_engine.dart';
import 'keypad.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({
    super.key,
    this.store,
    this.factory,
    this.pinService,
  });

  final SetupStore? store;
  final TriggerServiceFactory? factory;
  final PinService? pinService;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final CalculatorEngine _engine = CalculatorEngine();
  final TripleTapDetector _tripleTap = TripleTapDetector();
  late final SetupStore _store = widget.store ?? SetupStore(SecureStore());
  late final TriggerServiceFactory _factory =
      widget.factory ?? DeviceTriggerServiceFactory.instance;
  late final PinService _pinService = widget.pinService ?? ComputePinService();
  TriggerController? _controller;
  bool _tripleTapEnabled = true;

  @override
  void initState() {
    super.initState();
    unawaited(_housekeeping());
  }

  Future<void> _housekeeping() async {
    // Local file cleanup only: no Firebase on the calculator path (SPEC 8.6).
    await cleanStaleAudio(maxAge: Timing.audioLocalMaxAge);
    final enabled = await _store.readTripleTapEnabled();
    if (mounted) {
      setState(() => _tripleTapEnabled = enabled);
    }
  }

  Future<void> _openPinGate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PinGateScreen(
          store: _store,
          pinService: _pinService,
        ),
      ),
    );
  }

  Future<void> _handleKey(KeyDef def) async {
    if (def.action == KeyAction.equals) {
      await _handleEquals();
      return;
    }
    setState(() {
      switch (def.action) {
        case KeyAction.digit:
          _engine.inputDigit(def.digit!);
        case KeyAction.decimal:
          _engine.inputDecimal();
        case KeyAction.operator:
          _engine.applyOperator(def.op!);
        case KeyAction.clear:
          _engine.clear();
        case KeyAction.sign:
          _engine.toggleSign();
        case KeyAction.percent:
          _engine.percent();
        case KeyAction.equals:
          break;
      }
    });
  }

  Future<void> _handleEquals() async {
    final entry = _engine.rawEntry;
    if (looksLikePin(entry) && await _pinAction(entry)) {
      return;
    }
    setState(_engine.equals);
  }

  /// A PIN entry on equals either cancels the active incident or starts one.
  /// Returns true when the press was consumed by the PIN path (SPEC 13.1, 14).
  Future<bool> _pinAction(String entry) async {
    final pin = await _store.readPin();
    if (pin == null || entry.length != pin.length) {
      return false;
    }
    final matched = await _pinService.verify(entry, pin);
    if (!matched) {
      return false;
    }
    final controller = _controller;
    if (controller != null && controller.isActive) {
      _clearDisplay(pulse: false);
      await controller.cancel();
      return true;
    }
    final ready = await _setupReady();
    if (!ready) {
      _clearDisplay(pulse: false);
      return true;
    }
    _clearDisplay(pulse: true);
    await _startIncident(TriggerKind.pin);
    return true;
  }

  Future<void> _handleTripleTap() async {
    if (!_tripleTapEnabled) {
      return;
    }
    if (_controller?.isActive ?? false) {
      return;
    }
    if (!await _setupReady()) {
      _clearDisplay(pulse: false);
      return;
    }
    _clearDisplay(pulse: true);
    await _startIncident(TriggerKind.tripleTap);
  }

  Future<bool> _setupReady() async {
    final pin = await _store.readPin();
    final contacts = await _store.readContacts();
    return pin != null && contacts.length >= ContactRules.required;
  }

  Future<void> _startIncident(TriggerKind kind) async {
    try {
      final controller = _controller ?? await _factory.build();
      _controller = controller;
      await controller.trigger(kind);
    } catch (_) {
      // No visible feedback on a failed start (SPEC 13.5).
    }
  }

  void _clearDisplay({required bool pulse}) {
    if (pulse) {
      HapticFeedback.vibrate();
    }
    if (mounted) {
      setState(_engine.clear);
    }
  }

  void _onDisplayTap() {
    if (_tripleTap.addTap()) {
      unawaited(_handleTripleTap());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Expanded(flex: 2, child: _buildDisplay()),
                  const SizedBox(height: 8),
                  Expanded(flex: 5, child: _buildKeypad()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    final text = _engine.display;
    final size = displayFontSize(text.length);
    return GestureDetector(
      key: const ValueKey('calculator-display'),
      behavior: HitTestBehavior.opaque,
      onTap: _onDisplayTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: 'Display $text',
              child: Align(
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    text,
                    maxLines: 1,
                    textScaler: TextScaler.noScaling,
                    style: AppTypography.display.copyWith(fontSize: size),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const LedgerRule(),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Keypad(
      onKey: (def) => unawaited(_handleKey(def)),
      onAcLongPress: () => unawaited(_openPinGate()),
    );
  }
}
