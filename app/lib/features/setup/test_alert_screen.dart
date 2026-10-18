import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/secure_store.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../incident/incident.dart';
import '../incident/sms_sender.dart';
import '../trigger/trigger_controller.dart';

enum _TestPhase { confirming, running, summary }

class TestAlertScreen extends StatefulWidget {
  const TestAlertScreen({super.key, required this.store});

  final SetupStore store;

  @override
  State<TestAlertScreen> createState() => _TestAlertScreenState();
}

class _TestAlertScreenState extends State<TestAlertScreen> {
  _TestPhase _phase = _TestPhase.confirming;
  List<String> _names = const <String>[];
  List<String> _statuses = const <String>[];
  String _summary = '';
  TriggerController? _controller;

  Future<void> _send() async {
    final contacts = await widget.store.readContacts();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _TestPhase.running;
      _names = [for (final contact in contacts) contact.name];
      _statuses = List<String>.filled(contacts.length, 'Sending');
    });
    try {
      final controller = await DeviceTriggerServiceFactory.instance.build();
      _controller = controller;
      final decision = await controller.trigger(TriggerKind.test);
      if (decision != TriggerDecision.started) {
        if (!mounted) {
          return;
        }
        setState(() {
          _phase = _TestPhase.summary;
          _summary = 'The test did not start. Check your setup and try again.';
        });
        return;
      }
      final results = await controller.deliveryResult();
      await widget.store.writeLastTest(DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _statuses = [for (final result in results) statusLabel(result.status)];
        final total = _names.length;
        final sent =
            results.where((result) => result.status == SmsResult.sent).length;
        _summary = sent == total && total > 0
            ? 'Test sent to $total of $total contacts.'
            : 'Test finished. $sent of $total contacts got the message.';
        _phase = _TestPhase.summary;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _TestPhase.summary;
        _summary = 'The test could not run. Check your setup and try again.';
      });
    }
  }

  String statusLabel(String status) => switch (status) {
        SmsResult.sent => 'Sent',
        SmsResult.permissionDenied => 'No permission',
        _ => 'Failed',
      };

  Future<void> _stopTest() async {
    await _controller?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _TestPhase.confirming => _confirming(),
      _TestPhase.running => _progress(),
      _TestPhase.summary => _summaryView(),
    };
  }

  Widget _confirming() {
    return SetupScaffold(
      title: 'Test alert',
      actions: [
        FilledButton(
          onPressed: () => unawaited(_send()),
          child: const Text('Send test'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
      children: [
        Text('Send a test alert now?', style: AppTypography.title),
        const SizedBox(height: 12),
        Text(
          'This sends a real text to your three contacts and records '
          '5 seconds of audio. The link works for one hour.',
          style: AppTypography.body,
        ),
      ],
    );
  }

  Widget _progress() {
    return SetupScaffold(
      title: 'Test alert',
      actions: [
        TextButton(
          onPressed: () => unawaited(_stopTest()),
          child: const Text('Cancel'),
        ),
      ],
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 24),
        ..._statusRows(),
      ],
    );
  }

  Widget _summaryView() {
    return SetupScaffold(
      title: 'Test alert',
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
      children: [
        Text(_summary, style: AppTypography.body),
        const SizedBox(height: 16),
        ..._statusRows(),
      ],
    );
  }

  List<Widget> _statusRows() => [
        for (var i = 0; i < _names.length; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_names[i], style: AppTypography.rowLabel),
                    ),
                    Text(
                      i < _statuses.length ? _statuses[i] : 'Sending',
                      style: AppTypography.secondary.copyWith(
                        color: i < _statuses.length &&
                                _statuses[i] == 'Sent'
                            ? Palette.statusOk
                            : Palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const LedgerRule(color: Palette.rule),
            ],
          ),
      ];
}
