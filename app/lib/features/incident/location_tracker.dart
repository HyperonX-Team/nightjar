import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../core/constants.dart';
import 'incident_repository.dart';

abstract class LocationSource {
  /// Last known position, only when it is younger than 2 minutes and under
  /// 100 meters (SPEC 16.1).
  Future<AcceptedFix?> cachedFix();

  Future<AcceptedFix?> firstFix(Duration timeout);

  /// Fresh fixes, already filtered for accuracy and throttled to 10 seconds.
  Stream<AcceptedFix> updates(Duration throttle);
}

class DeviceLocationSource implements LocationSource {
  @override
  Future<AcceptedFix?> cachedFix() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        return null;
      }
      final age = DateTime.now().difference(position.timestamp);
      if (age > Timing.cachedFixMaxAge ||
          position.accuracy > SignalQuality.cachedFixMaxAccuracyMeters) {
        return null;
      }
      return _toFix(position);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AcceptedFix?> firstFix(Duration timeout) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _toFix(position);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AcceptedFix> updates(Duration throttle) {
    DateTime? lastAccepted;
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).transform(
      StreamTransformer<Position, AcceptedFix>.fromHandlers(
        handleData: (position, sink) {
          final fix = _toFix(position);
          if (fix == null) {
            return;
          }
          final now = DateTime.now();
          if (lastAccepted != null &&
              now.difference(lastAccepted!) < throttle) {
            return;
          }
          lastAccepted = now;
          sink.add(fix);
        },
      ),
    );
  }

  AcceptedFix? _toFix(Position position) {
    if (position.accuracy > SignalQuality.rejectAccuracyMeters) {
      return null;
    }
    return AcceptedFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      at: position.timestamp,
    );
  }
}
