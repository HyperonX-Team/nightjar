import 'package:flutter/services.dart';

import '../../core/constants.dart';
import 'incident_repository.dart';

class SmsResult {
  const SmsResult({required this.status, this.reason});

  static const sent = 'sent';
  static const failed = 'failed';
  static const permissionDenied = 'permission_denied';

  final String status;
  final String? reason;

  static SmsResult fromMap(Object? raw) {
    if (raw is Map) {
      return SmsResult(
        status: raw['status'] as String? ?? failed,
        reason: raw['reason'] as String?,
      );
    }
    return const SmsResult(status: failed, reason: 'malformed_result');
  }
}

abstract class AlertMessenger {
  Future<List<SmsResult>> sendAlerts({
    required List<String> phones,
    required String message,
    required String token,
  });
}

class PlatformSmsSender implements AlertMessenger {
  static const MethodChannel _channel = MethodChannel(NativeChannels.sms);

  @override
  Future<List<SmsResult>> sendAlerts({
    required List<String> phones,
    required String message,
    required String token,
  }) async {
    try {
      final response = await _channel
          .invokeMethod<Map<Object?, Object?>>('sendAlerts', <String, Object?>{
        'phones': phones,
        'message': message,
        'token': token,
      });
      final raw = response?['results'];
      final results = raw is List
          ? [for (final item in raw) SmsResult.fromMap(item)]
          : const <SmsResult>[];
      if (results.length == phones.length) {
        return results;
      }
      return [
        for (var i = 0; i < phones.length; i++)
          i < results.length
              ? results[i]
              : const SmsResult(status: SmsResult.failed, reason: 'missing'),
      ];
    } on PlatformException catch (error) {
      return _allFailed(phones, error.code);
    } on MissingPluginException {
      return _allFailed(phones, 'channel_unavailable');
    }
  }

  List<SmsResult> _allFailed(List<String> phones, String reason) => [
        for (final _ in phones)
          SmsResult(status: SmsResult.failed, reason: reason),
      ];
}

/// Composes the one message every contact receives. The template is fixed by
/// SPEC 17.2 and must stay free of the product name and safety words.
class MessageComposer {
  static String build({
    required String ownerName,
    required String token,
    AcceptedFix? fix,
  }) {
    final buffer = StringBuffer('Alert from ${_safeName(ownerName)}.');
    if (fix != null) {
      buffer.write(
        ' Live location: '
        '${PageLinks.maps(fix.latitude, fix.longitude)}',
      );
    }
    buffer.write(' Details: ${PageLinks.incident(token)}');
    return buffer.toString();
  }

  /// Returns the broken rule, or null when the message is sendable.
  static String? validate(String message) {
    if (message.length > EditedCopy.maxMessageLength) {
      return 'too_long';
    }
    if (message.codeUnits.any((unit) => unit > 127)) {
      return 'not_ascii';
    }
    final lower = message.toLowerCase();
    for (final term in EditedCopy.forbiddenTerms) {
      if (lower.contains(term)) {
        return 'forbidden_term';
      }
    }
    return null;
  }

  static String _safeName(String ownerName) {
    final name = ownerName.trim();
    if (name.isEmpty ||
        name.length > ContactRules.ownerNameMaxLength ||
        name.codeUnits.any((unit) => unit > 127)) {
      return ContactRules.defaultOwnerName;
    }
    final lower = name.toLowerCase();
    if (EditedCopy.forbiddenTerms.any(lower.contains)) {
      return ContactRules.defaultOwnerName;
    }
    return name;
  }
}
