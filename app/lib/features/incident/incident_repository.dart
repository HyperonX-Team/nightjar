import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import 'incident.dart';

/// One accepted location sample.
class AcceptedFix {
  const AcceptedFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.at,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime at;

  bool get lowAccuracy => accuracyMeters > SignalQuality.lowAccuracyMeters;
}

abstract class IncidentWriter {
  Future<Incident> create({
    required TriggerKind trigger,
    required String ownerName,
    required String appVersion,
  });

  Future<void> publishFix({
    required Incident incident,
    required AcceptedFix fix,
  });

  Future<void> publishDelivery({
    required String token,
    required List<DeliveryEntry> delivery,
  });

  Future<void> publishAudio({
    required String token,
    required AudioStatus status,
    String? path,
    int? durationSec,
    int? sizeBytes,
  });

  Future<void> markEnded({required String token});
}

class FirestoreIncidentRepository implements IncidentWriter {
  FirestoreIncidentRepository({
    required this.ownerUid,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String ownerUid;
  final FirebaseFirestore _firestore;

  @override
  Future<Incident> create({
    required TriggerKind trigger,
    required String ownerName,
    required String appVersion,
  }) async {
    final now = DateTime.now();
    final incident = Incident(
      token: generateToken(),
      ownerUid: ownerUid,
      trigger: trigger,
      createdAt: now,
      expiresAt: expiryFor(trigger, now),
      appVersion: appVersion,
      ownerName: ownerName,
    );
    await _firestore
        .collection(FirebaseNames.incidents)
        .doc(incident.token)
        .set(<String, Object?>{
      'ownerUid': ownerUid,
      'schemaVersion': AppInfo.schemaVersion,
      'status': 'active',
      'trigger': triggerName(trigger),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(incident.expiresAt),
      'locationUnavailable': true,
      'contactsAlerted': 0,
      'delivery': <Map<String, Object>>[],
      'appVersion': appVersion,
      if (ownerName.isNotEmpty) 'name': ownerName,
    });
    return incident;
  }

  @override
  Future<void> publishFix({
    required Incident incident,
    required AcceptedFix fix,
  }) async {
    final document = _firestore
        .collection(FirebaseNames.incidents)
        .doc(incident.token);
    final point = GeoPoint(fix.latitude, fix.longitude);
    final batch = _firestore.batch()
      ..update(document, <String, Object?>{
        'location': point,
        'accuracyMeters': fix.accuracyMeters,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'locationUnavailable': false,
        if (fix.lowAccuracy) 'lowAccuracy': true,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(document.collection(FirebaseNames.pings).doc(), <String, Object?>{
        'location': point,
        'accuracyMeters': fix.accuracyMeters,
        'at': FieldValue.serverTimestamp(),
        'atClient': Timestamp.fromDate(fix.at),
        'expiresAt': Timestamp.fromDate(incident.expiresAt),
      });
    await batch.commit();
  }

  @override
  Future<void> publishDelivery({
    required String token,
    required List<DeliveryEntry> delivery,
  }) async {
    final sent = delivery.where((entry) => entry.status == 'sent').length;
    await _incident(token).update(<String, Object?>{
      'contactsAlerted': sent,
      'delivery': [for (final entry in delivery) entry.toMap()],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> publishAudio({
    required String token,
    required AudioStatus status,
    String? path,
    int? durationSec,
    int? sizeBytes,
  }) async {
    await _incident(token).update(<String, Object?>{
      'audio': <String, Object?>{
        'status': status.name,
        if (path != null) 'path': path,
        if (durationSec != null) 'durationSec': durationSec,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (status == AudioStatus.ready || status == AudioStatus.partial)
          'uploadedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markEnded({required String token}) async {
    await _incident(token).update(<String, Object?>{
      'status': 'ended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  DocumentReference<Map<String, dynamic>> _incident(String token) =>
      _firestore.collection(FirebaseNames.incidents).doc(token);
}
