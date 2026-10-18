import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/palette.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';

/// One row of the permission stack, backed by the real platform state.
class PermissionRowState {
  const PermissionRowState({
    required this.title,
    required this.explanation,
    required this.permission,
    required this.status,
    this.fullAlert = false,
    this.recommended = false,
  });

  final String title;
  final String explanation;
  final Permission permission;
  final PermissionStatus status;
  final bool fullAlert;
  final bool recommended;

  bool get granted => status.isGranted;

  bool get permanentlyDenied => status.isPermanentlyDenied;

  /// Notification and battery rows do not count toward the amber summary: the
  /// service still runs without them (SPEC 12.1, 12.5).
  bool get countsTowardSummary => fullAlert || recommended;
}

/// A permission query that degrades to denied instead of throwing when the
/// platform channel is unavailable (for example in widget tests).
Future<PermissionStatus> _statusOf(Permission permission) async {
  try {
    return await permission.status;
  } catch (_) {
    return PermissionStatus.denied;
  }
}

Future<List<PermissionRowState>> readPermissionRows() async => [
      PermissionRowState(
        title: 'Microphone',
        explanation: 'Records 30 seconds when you trigger an alert.',
        permission: Permission.microphone,
        status: await _statusOf(Permission.microphone),
        fullAlert: true,
      ),
      PermissionRowState(
        title: 'Location',
        explanation: 'Shares your position for 15 minutes.',
        permission: Permission.location,
        status: await _statusOf(Permission.location),
        fullAlert: true,
      ),
      PermissionRowState(
        title: 'Background location',
        explanation: 'Keeps sharing when the app is not on screen.',
        permission: Permission.locationAlways,
        status: await _statusOf(Permission.locationAlways),
        recommended: true,
      ),
      PermissionRowState(
        title: 'Notifications',
        explanation:
            'Android shows a small notification while an alert is active. '
            'It cannot be hidden.',
        permission: Permission.notification,
        status: await _statusOf(Permission.notification),
      ),
      PermissionRowState(
        title: 'SMS',
        explanation: 'Sends the alert text to your contacts.',
        permission: Permission.sms,
        status: await _statusOf(Permission.sms),
        fullAlert: true,
      ),
      PermissionRowState(
        title: 'Battery',
        explanation:
            'Some phones stop background work. Allow Nightjar to keep running.',
        permission: Permission.ignoreBatteryOptimizations,
        status: await _statusOf(Permission.ignoreBatteryOptimizations),
      ),
    ];

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.rowsLoader});

  final Future<List<PermissionRowState>> Function()? rowsLoader;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  List<PermissionRowState> _rows = const <PermissionRowState>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final rows =
        await (widget.rowsLoader ?? readPermissionRows).call();
    if (!mounted) {
      return;
    }
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _request(PermissionRowState row) async {
    try {
      if (row.permanentlyDenied) {
        await openAppSettings();
        return;
      }
      await row.permission.request();
    } catch (_) {
      // Leave the row as it was when the platform channel is unavailable.
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Permissions',
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LinearProgressIndicator(),
          )
        else ...[
          for (final row in _rows) _PermissionRowView(row: row, onAction: () => _request(row)),
          const SizedBox(height: 24),
          Text(
            'You can finish setup without these. The test alert will show '
            'what is missing.',
            style: AppTypography.secondary,
          ),
        ],
      ],
    );
  }
}

class _PermissionRowView extends StatelessWidget {
  const _PermissionRowView({required this.row, required this.onAction});

  final PermissionRowState row;
  final VoidCallback onAction;

  String get _statusText {
    if (row.granted) {
      return 'Granted';
    }
    if (row.status.isDenied) {
      return 'Not requested';
    }
    return 'Denied';
  }

  @override
  Widget build(BuildContext context) {
    final mark = row.granted ? SetupRowState.ok : SetupRowState.warn;
    final badge = row.fullAlert
        ? 'Needed for a full alert'
        : (row.recommended ? 'Recommended' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusMark(mark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title, style: AppTypography.rowLabel),
                    if (badge != null)
                      Text(badge, style: AppTypography.secondary),
                    const SizedBox(height: 4),
                    Text(row.explanation, style: AppTypography.body),
                    const SizedBox(height: 4),
                    Text(
                      _statusText,
                      style: AppTypography.secondary.copyWith(
                        color:
                            row.granted ? Palette.statusOk : Palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!row.granted)
                TextButton(
                  onPressed: onAction,
                  child: Text(row.permanentlyDenied ? 'Open settings' : 'Allow'),
                ),
            ],
          ),
        ),
        const LedgerRule(color: Palette.rule),
      ],
    );
  }
}
