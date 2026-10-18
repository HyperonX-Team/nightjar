import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightjar/theme/palette.dart';

double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('reports the measured ratios for the verification log', () {
    void report(String label, Color a, Color b) {
      debugPrint('$label: ${contrastRatio(a, b).toStringAsFixed(2)}:1');
    }

    report('ink on paper', Palette.ink, Palette.paper);
    report('oxide on paper', Palette.oxide, Palette.paper);
    report('paper on oxide', Palette.paper, Palette.oxide);
    report('ink on key surface', Palette.ink, Palette.keySurface);
    report('ink on pressed key', Palette.ink, Palette.keyPressed);
    report('muted ink on paper', Palette.inkMuted, Palette.paper);
    report('ok status on paper', Palette.statusOk, Palette.paper);
    report('warn status on paper', Palette.statusWarn, Palette.paper);
    report('bad status on paper', Palette.statusBad, Palette.paper);
  });

  test('ink on paper exceeds AAA', () {
    expect(contrastRatio(Palette.ink, Palette.paper), greaterThan(13.0));
  });

  test('accent oxide on paper meets AA', () {
    expect(contrastRatio(Palette.oxide, Palette.paper), greaterThanOrEqualTo(4.5));
  });

  test('paper on oxide meets AA', () {
    expect(contrastRatio(Palette.paper, Palette.oxide), greaterThanOrEqualTo(4.5));
  });

  test('ink on key surface stays above 10 to 1', () {
    expect(
      contrastRatio(Palette.ink, Palette.keySurface),
      greaterThanOrEqualTo(10.0),
    );
  });

  test('pressed key keeps contrast while darkening', () {
    final resting = contrastRatio(Palette.ink, Palette.keySurface);
    final pressed = contrastRatio(Palette.ink, Palette.keyPressed);
    expect(pressed, greaterThanOrEqualTo(10.0));
    expect(pressed, lessThan(resting));
  });

  test('secondary text meets AA', () {
    expect(
      contrastRatio(Palette.inkMuted, Palette.paper),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('status colors meet AA on paper', () {
    for (final color in [
      Palette.statusOk,
      Palette.statusWarn,
      Palette.statusBad,
    ]) {
      expect(
        contrastRatio(color, Palette.paper),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
