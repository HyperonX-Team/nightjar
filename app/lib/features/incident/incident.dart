import 'dart:convert';

import '../../core/constants.dart';
import '../trigger/pin_hasher.dart' show randomBytes;

enum IncidentStatus { active, ended }

enum TriggerKind { pin, tripleTap, test }

enum AudioStatus { pending, ready, failed, partial }

/// One row of `delivery`. Channel and status only, never a number (SPEC 18.2).
class DeliveryEntry {
  const DeliveryEntry({required this.channel, required this.status});

  final String channel;
  final String status;

  Map<String, Object> toMap() => {'channel': channel, 'status': status};
}

class Incident {
  const Incident({
    required this.token,
    required this.ownerUid,
    required this.trigger,
    required this.createdAt,
    required this.expiresAt,
    required this.appVersion,
    this.ownerName = '',
  });

  final String token;
  final String ownerUid;
  final TriggerKind trigger;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String appVersion;
  final String ownerName;
}

/// 24 random bytes as base64url without padding: the document id and the page
/// path, 32 characters (SPEC 18.1).
String generateToken() =>
    base64Url.encode(randomBytes(24)).replaceAll('=', '');

DateTime expiryFor(TriggerKind trigger, DateTime from) => from.add(
      trigger == TriggerKind.test
          ? Timing.testIncidentExpiry
          : Timing.incidentExpiry,
    );

String triggerName(TriggerKind trigger) => switch (trigger) {
      TriggerKind.pin => 'pin',
      TriggerKind.tripleTap => 'triple_tap',
      TriggerKind.test => 'test',
    };

TriggerKind? triggerFromName(String name) => switch (name) {
      'pin' => TriggerKind.pin,
      'triple_tap' => TriggerKind.tripleTap,
      'test' => TriggerKind.test,
      _ => null,
    };
