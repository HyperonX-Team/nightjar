/// Values the spec fixes in more than one place. SPEC.md wins over this file.
class AppInfo {
  static const visibleName = 'Calculator';
  static const applicationId = 'com.tally.calculator';
  static const schemaVersion = 1;
}

class FirebaseNames {
  static const incidents = 'incidents';
  static const pings = 'pings';
  static const emulatorHost = '10.0.2.2';
}

class PageLinks {
  /// Firebase project `nightjar-8d561` hosting domain. Change this together
  /// with web/contact/config.js.
  static const base = 'https://nightjar-8d561.web.app';

  static String incident(String token) => '$base/i/$token';

  static String maps(double latitude, double longitude) =>
      'https://maps.google.com/?q=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

class Timing {
  static const pinLongPress = Duration(milliseconds: 2000);
  static const pinLongPressMoveTolerance = 24.0;
  static const tripleTapGap = Duration(milliseconds: 350);
  static const tripleTapTotal = Duration(milliseconds: 700);
  static const triggerDebounce = Duration(milliseconds: 2000);
  static const triggerCooldown = Duration(seconds: 10);
  static const recordingWindow = Duration(seconds: 30);
  static const testRecordingWindow = Duration(seconds: 5);
  static const locationWindow = Duration(minutes: 15);
  static const testLocationWindow = Duration(minutes: 1);
  static const firstFixTimeout = Duration(seconds: 10);
  static const smsTimeout = Duration(seconds: 20);
  static const serviceHardCap = Duration(minutes: 20);
  static const locationThrottle = Duration(seconds: 10);
  static const cachedFixMaxAge = Duration(minutes: 2);
  static const incidentExpiry = Duration(hours: 24);
  static const testIncidentExpiry = Duration(hours: 1);
  static const audioLocalMaxAge = Duration(hours: 1);
  static const uploadRetryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];
}

class SignalQuality {
  static const cachedFixMaxAccuracyMeters = 100.0;
  static const lowAccuracyMeters = 500.0;
  static const rejectAccuracyMeters = 2000.0;
  static const staleFixAge = Duration(minutes: 2);
}

class AudioFormat {
  static const sampleRate = 16000;
  static const bitRate = 64000;
  static const maxUploadBytes = 2 * 1024 * 1024;
}

class PinRules {
  static const minLength = 4;
  static const maxLength = 8;
  static const iterations = 210000;
  static const saltBytes = 16;
  static const keyBytes = 32;
  static const maxAttempts = 5;
  static const lockoutLadder = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];
}

class ContactRules {
  static const required = 3;
  static const nameMaxLength = 40;
  static const ownerNameMaxLength = 20;
  static const defaultOwnerName = 'a contact';
}

class ServiceNotification {
  static const serviceId = 2107;
  static const channelId = 'calculator_service';
  static const channelName = 'Calculator';
  static const title = 'Calculator';
  static const text = 'Active';
}

class NativeChannels {
  static const sms = 'dev.nightjar/sms';
}

class EditedCopy {
  static const maxMessageLength = 300;
  static const forbiddenTerms = <String>['nightjar', 'sos', 'abuse', 'help me'];
}
