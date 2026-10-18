import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/secure_store.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../incident/audio_recorder.dart';
import '../incident/upload_queue.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.store});

  final SetupStore store;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (build ${info.buildNumber})');
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteConfirmDialog(),
    );
    if (confirmed != true) {
      return;
    }
    final queue = UploadQueue();
    final entry = await queue.read();
    if (entry != null) {
      await deleteLocalAudio(entry.audioPath);
    }
    await queue.clear();
    await widget.store.clearAllSettings();
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'About',
      actions: [
        FilledButton(
          onPressed: () => unawaited(_deleteAll()),
          child: const Text('Delete all settings'),
        ),
      ],
      children: [
        SetupRow(label: 'Version', status: _version.isEmpty ? '...' : _version),
        const SizedBox(height: 24),
        Text(
          'Safety settings are stored on this phone. Alerts and locations are '
          'removed automatically after 24 hours. Removal can take a little '
          'longer.',
          style: AppTypography.body,
        ),
      ],
    );
  }
}

class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog();

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _field.text.trim() == 'DELETE';
    return AlertDialog(
      title: const Text('Delete all settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This removes your PIN, contacts, and any pending upload. '
            'Existing alerts expire on their own.',
          ),
          const SizedBox(height: 16),
          const Text('Type DELETE to confirm.'),
          const SizedBox(height: 8),
          TextField(
            controller: _field,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ready ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete all settings'),
        ),
      ],
    );
  }
}
