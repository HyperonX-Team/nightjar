import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../services/secure_store.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../trigger/pin_hasher.dart';
import 'setup_status_screen.dart';

enum PinGatePurpose { unlockOrCreate, changePin }

class PinGateScreen extends StatefulWidget {
  const PinGateScreen({
    super.key,
    required this.store,
    this.purpose = PinGatePurpose.unlockOrCreate,
    this.pinService,
  });

  final SetupStore store;
  final PinGatePurpose purpose;
  final PinService? pinService;

  @override
  State<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends State<PinGateScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final PinService _pinService = widget.pinService ?? ComputePinService();

  PinRecord? _record;
  LockoutState _lockout = const LockoutState();
  Timer? _lockTimer;
  bool _loading = true;
  bool _creating = false;
  bool _showPin = false;
  String? _error;
  String? _verifiedCurrentPin;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final record = await widget.store.readPin();
    final lockout = await widget.store.readLockout();
    if (!mounted) {
      return;
    }
    setState(() {
      _record = record;
      _lockout = lockout;
      _creating = record == null;
      _loading = false;
    });
    _syncLockTimer();
  }

  void _syncLockTimer() {
    _lockTimer?.cancel();
    if (_lockout.isLocked(DateTime.now())) {
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_lockout.isLocked(DateTime.now())) {
          _lockTimer?.cancel();
        }
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  bool get _locked => _lockout.isLocked(DateTime.now());

  Future<void> _submit() async {
    if (_loading || _locked) {
      return;
    }
    if (_creating) {
      await _createPin(_pinController.text);
      return;
    }
    await _verify(_pinController.text);
  }

  Future<void> _verify(String pin) async {
    final record = _record;
    if (record == null) {
      return;
    }
    final matched = await _pinService.verify(pin, record);
    if (!mounted) {
      return;
    }
    if (matched) {
      await widget.store.writeLockout(_lockout.afterSuccess());
      if (widget.purpose == PinGatePurpose.changePin) {
        setState(() {
          _verifiedCurrentPin = pin;
          _creating = true;
          _error = null;
          _pinController.clear();
        });
        return;
      }
      await _openStatus();
      return;
    }
    final next = _lockout.afterFailure(DateTime.now());
    await widget.store.writeLockout(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _lockout = next;
      _error = next.isLocked(DateTime.now())
          ? lockoutMessage(next.remaining(DateTime.now()))
          : 'Incorrect PIN. Try again.';
      _pinController.clear();
    });
    _syncLockTimer();
  }

  Future<void> _createPin(String pin) async {
    final ruleError = validatePinRules(pin);
    if (ruleError != null) {
      setState(() => _error = ruleError);
      return;
    }
    if (widget.purpose == PinGatePurpose.changePin && pin == _verifiedCurrentPin) {
      setState(() => _error = 'Choose a PIN you have not used before.');
      return;
    }
    if (pin != _confirmController.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    final record = await _pinService.create(pin);
    await widget.store.writePin(record);
    await widget.store.writeLockout(const LockoutState());
    if (!mounted) {
      return;
    }
    if (widget.purpose == PinGatePurpose.changePin) {
      Navigator.of(context).pop();
      return;
    }
    await _openStatus();
  }

  Future<void> _openStatus() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SetupStatusScreen(store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _creating ? 'Create a PIN' : 'Enter PIN';
    return SetupScaffold(
      title: title,
      actions: [
        FilledButton(
          onPressed: _loading || _locked ? null : () => unawaited(_submit()),
          child: Text(_creating ? 'Continue' : 'Unlock'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to calculator'),
        ),
      ],
      children: [
        _pinField(
          controller: _pinController,
          label: 'PIN',
          autofocus: true,
        ),
        if (_creating) ...[
          const SizedBox(height: 16),
          _pinField(controller: _confirmController, label: 'Repeat PIN'),
        ],
        const SizedBox(height: 12),
        if (_locked)
          Text(
            lockoutMessage(_lockout.remaining(DateTime.now())),
            style: const TextStyle(
              fontFamily: 'IBMPlexSans',
              fontSize: 15,
              color: Palette.oxide,
            ),
          )
        else if (_error != null)
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'IBMPlexSans',
              fontSize: 15,
              color: Palette.oxide,
            ),
          )
        else if (_creating)
          Text(
            'Use 4 to 8 digits. Avoid repeated or sequential numbers.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: !_showPin,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(PinRules.maxLength),
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: IconButton(
          onPressed: () => setState(() => _showPin = !_showPin),
          icon: Icon(
            _showPin ? Icons.visibility_off : Icons.visibility,
            size: 20,
          ),
          tooltip: _showPin ? 'Hide PIN' : 'Show PIN',
        ),
      ),
      onSubmitted: (_) => unawaited(_submit()),
    );
  }
}
