import '../../core/constants.dart';

/// Three taps on the display, each within 350 ms of the previous tap and the
/// whole sequence within 700 ms (SPEC 13.1).
class TripleTapDetector {
  TripleTapDetector({
    this.gap = Timing.tripleTapGap,
    this.total = Timing.tripleTapTotal,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration gap;
  final Duration total;
  final DateTime Function() _clock;
  final List<DateTime> _taps = <DateTime>[];

  bool addTap([DateTime? at]) {
    final now = at ?? _clock();
    if (_taps.isNotEmpty && now.difference(_taps.last) > gap) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length < 3) {
      return false;
    }
    final span = _taps.last.difference(_taps.first);
    final accepted = span <= total;
    _taps.clear();
    return accepted;
  }

  void reset() => _taps.clear();
}

/// The PIN trigger accepts 4 to 8 digits exactly as typed. The display groups
/// thousands, so the check runs on the raw entry (SPEC 13.1).
bool looksLikePin(String rawEntry) =>
    RegExp(r'^\d{4,8}$').hasMatch(rawEntry);
