import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/core/constants.dart';
import 'package:nightjar/features/trigger/trigger_detector.dart';

void main() {
  final base = DateTime(2026, 10, 17, 12);

  TripleTapDetector detector() => TripleTapDetector();

  group('triple tap timing', () {
    test('three taps within 350 ms each are accepted', () {
      final subject = detector();
      expect(subject.addTap(base), isFalse);
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 300))),
        isFalse,
      );
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 600))),
        isTrue,
      );
    });

    test('a 351 ms gap breaks the sequence', () {
      final subject = detector();
      subject.addTap(base);
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 351))),
        isFalse,
      );
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 702))),
        isFalse,
      );
    });

    test('an exactly 350 ms gap is accepted', () {
      final subject = detector();
      subject.addTap(base);
      subject.addTap(base.add(const Duration(milliseconds: 350)));
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 700))),
        isTrue,
      );
    });

    test('a sequence longer than 700 ms is rejected', () {
      final subject = detector();
      subject.addTap(base);
      subject.addTap(base.add(const Duration(milliseconds: 350)));
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 701))),
        isFalse,
      );
    });

    test('a long pause resets the sequence', () {
      final subject = detector();
      subject.addTap(base);
      subject.addTap(base.add(const Duration(milliseconds: 100)));
      subject.addTap(base.add(const Duration(seconds: 5)));
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 5100))),
        isFalse,
      );
    });

    test('a fourth fast tap starts a new sequence', () {
      final subject = detector();
      subject.addTap(base);
      subject.addTap(base.add(const Duration(milliseconds: 100)));
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 200))),
        isTrue,
      );
      expect(
        subject.addTap(base.add(const Duration(milliseconds: 300))),
        isFalse,
      );
    });

    test('the detector uses its own clock by default', () {
      final subject = detector();
      var accepted = false;
      for (var i = 0; i < 3; i++) {
        accepted = subject.addTap();
      }
      expect(accepted, isTrue);
    });
  });

  group('pin shaped entry', () {
    test('four digits look like a PIN', () => expect(looksLikePin('4826'), isTrue));
    test('eight digits look like a PIN',
        () => expect(looksLikePin('48260317'), isTrue));
    test('three digits do not', () => expect(looksLikePin('482'), isFalse));
    test('nine digits do not', () => expect(looksLikePin('482603171'), isFalse));
    test('a decimal entry does not',
        () => expect(looksLikePin('12.5'), isFalse));
    test('a negative entry does not',
        () => expect(looksLikePin('-4826'), isFalse));
    test('a grouped entry does not',
        () => expect(looksLikePin('4,826'), isFalse));
    test('an empty entry does not', () => expect(looksLikePin(''), isFalse));
    test('the default trip window matches the spec', () {
      expect(Timing.tripleTapGap, const Duration(milliseconds: 350));
      expect(Timing.tripleTapTotal, const Duration(milliseconds: 700));
    });
  });
}
