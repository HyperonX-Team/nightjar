import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants.dart';
import '../../core/time.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/secure_store.dart';
import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../incident/audio_recorder.dart';
import '../incident/upload_queue.dart';
import '../trigger/pin_hasher.dart';
import 'about_screen.dart';
import 'contacts_screen.dart';
import 'permissions_screen.dart';
import 'pin_gate_screen.dart';
import 'test_alert_screen.dart';

class SetupStatusScreen extends StatefulWidget {
  const SetupStatusScreen({
    super.key,
    required this.store,
    this.pinService,
    this.rowsLoader,
    this.batteryGranted,
  });

  final SetupStore store;
  final PinService? pinService;
  final Future<List<PermissionRowState>> Function()? rowsLoader;
  final Future<bool> Function()? batteryGranted;

  @override
  State<SetupStatusScreen> createState() => _SetupStatusScreenState();
}

class _SetupStatusScreenState extends State<SetupStatusScreen> {
  bool _loading = true;
  bool _hasPin = false;
  int _contactCount = 0;
  int _permissionIssues = 0;
  bool _batteryAllowed = false;
  DateTime? _lastTest;
  bool _tripleTap = true;
  String _ownerName = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final hasPin = (await widget.store.readPin()) != null;
    final contacts = await widget.store.readContacts();
    final lastTest = await widget.store.readLastTest();
    final tripleTap = await widget.store.readTripleTapEnabled();
    final ownerName = await widget.store.readOwnerName();
    final batteryGranted = await (widget.batteryGranted ?? _readBattery)();
    final rows =
        await (widget.rowsLoader ?? readPermissionRows).call();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasPin = hasPin;
      _contactCount = contacts.length;
      _lastTest = lastTest;
      _tripleTap = tripleTap;
      _ownerName = ownerName;
      _batteryAllowed = batteryGranted;
      _permissionIssues = rows
          .where((row) => row.countsTowardSummary && !row.granted)
          .length;
      _loading = false;
    });
    unawaited(_retryPendingUpload());
  }

  static Future<bool> _readBattery() async {
    try {
      return (await Permission.ignoreBatteryOptimizations.status).isGranted;
    } catch (_) {
      // No platform channel (tests, unsupported device): treat as restricted.
      return false;
    }
  }

  /// A failed audio upload is retried when setup is opened, inside the one hour
  /// window. This keeps Firebase off the calculator path (SPEC 8.6, 19.2).
  Future<void> _retryPendingUpload() async {
    try {
      final queue = UploadQueue();
      final entry = await queue.read();
      if (entry == null) {
        return;
      }
      if (entry.isExpired(DateTime.now())) {
        await deleteLocalAudio(entry.audioPath);
        await queue.clear();
        return;
      }
      await FirebaseBootstrap.ensureOwnerUid(widget.store);
      final uploaded = await StorageAudioUploader().upload(
        token: entry.token,
        path: entry.audioPath,
        durationSec: 0,
        recordedAt: entry.createdAt,
      );
      if (uploaded) {
        await deleteLocalAudio(entry.audioPath);
        await queue.clear();
      }
    } catch (_) {
      // The entry stays for the next open.
    }
  }

  bool get _incomplete =>
      !_hasPin ||
      _contactCount < ContactRules.required ||
      _permissionIssues > 0 ||
      !_batteryAllowed;

  Future<void> _editOwnerName() async {
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: _ownerName),
    );
    if (saved == null) {
      return;
    }
    await widget.store.writeOwnerName(saved);
    if (mounted) {
      setState(() => _ownerName = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Safety settings',
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TestAlertScreen(store: widget.store),
            ),
          ),
          child: const Text('Send a test alert'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LinearProgressIndicator(),
          )
        else ...[
          SetupRow(
            mark: _hasPin ? SetupRowState.ok : SetupRowState.warn,
            label: 'PIN',
            status: _hasPin ? 'Set' : 'Not set',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PinGateScreen(
                  store: widget.store,
                  purpose: PinGatePurpose.changePin,
                  pinService: widget.pinService,
                ),
              ),
            ),
          ),
          SetupRow(
            mark: _contactCount >= ContactRules.required
                ? SetupRowState.ok
                : SetupRowState.warn,
            label: 'Contacts',
            status: '$_contactCount of ${ContactRules.required}',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ContactsScreen(store: widget.store),
                ),
              );
              await _load();
            },
          ),
          SetupRow(
            mark: _permissionIssues == 0
                ? SetupRowState.ok
                : SetupRowState.warn,
            label: 'Permissions',
            status: _permissionIssues == 0
                ? 'All set'
                : '$_permissionIssues need attention',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PermissionsScreen(),
                ),
              );
              await _load();
            },
          ),
          SetupRow(
            mark: _batteryAllowed ? SetupRowState.ok : SetupRowState.warn,
            label: 'Battery',
            status: _batteryAllowed ? 'Allowed' : 'Restricted',
            onTap: () async {
              await Permission.ignoreBatteryOptimizations.request();
              await _load();
            },
          ),
          SetupRow(
            mark: _lastTest == null ? SetupRowState.pending : SetupRowState.ok,
            label: 'Test alert',
            status: _lastTest == null
                ? 'No test yet'
                : 'Last test: ${formatDateTime(_lastTest!)}',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TestAlertScreen(store: widget.store),
                ),
              );
              await _load();
            },
          ),
          SetupRow(
            label: 'Name in the alert',
            status: _ownerName.isEmpty
                ? 'Shows as ${ContactRules.defaultOwnerName}'
                : _ownerName,
            onTap: () => unawaited(_editOwnerName()),
          ),
          SetupRow(
            label: 'Triple-tap trigger',
            status: _tripleTap ? 'On' : 'Off',
            trailing: Switch(
              value: _tripleTap,
              onChanged: (value) async {
                await widget.store.writeTripleTapEnabled(value);
                if (mounted) {
                  setState(() => _tripleTap = value);
                }
              },
            ),
          ),
          SetupRow(
            label: 'Delete all settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AboutScreen(store: widget.store),
              ),
            ),
          ),
          if (_incomplete) ...[
            const SizedBox(height: 20),
            Text(
              'Finish the amber items before you rely on Nightjar.',
              style: AppTypography.body.copyWith(color: Palette.statusWarn),
            ),
          ],
        ],
      ],
    );
  }
}

/// The dialog owns its controller so the field is never rebuilt with a
/// disposed controller during the close animation.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name in the alert'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: ContactRules.ownerNameMaxLength,
        decoration: const InputDecoration(
          labelText: 'Name',
          counterText: '',
          hintText: ContactRules.defaultOwnerName,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
