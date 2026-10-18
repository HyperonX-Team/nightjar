import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/constants.dart';

/// The service callback performs no work. Recording and location run in the
/// main isolate and the foreground service only keeps the process alive
/// (SPEC 33.3).
@pragma('vm:entry-point')
void nightjarServiceCallback() {}

abstract class ProcessKeeper {
  Future<bool> start();

  Future<void> stop();
}

class ForegroundServiceKeeper implements ProcessKeeper {
  static bool _configured = false;

  static void _configure() {
    if (_configured) {
      return;
    }
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: ServiceNotification.channelId,
        channelName: ServiceNotification.channelName,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _configured = true;
  }

  @override
  Future<bool> start() async {
    _configure();
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: ServiceNotification.serviceId,
      notificationTitle: ServiceNotification.title,
      notificationText: ServiceNotification.text,
      callback: nightjarServiceCallback,
    );
    return result is ServiceRequestSuccess;
  }

  @override
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
