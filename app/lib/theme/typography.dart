import 'package:flutter/material.dart';

import 'palette.dart';

/// IBM Plex Sans for UI, IBM Plex Mono for the display only (DESIGN.md).
class AppTypography {
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';

  static const title = TextStyle(
    fontFamily: sans,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Palette.ink,
  );

  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 1.45,
    color: Palette.ink,
  );

  static const secondary = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 1.4,
    color: Palette.inkMuted,
  );

  static const rowLabel = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    color: Palette.ink,
  );

  static const button = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const key = TextStyle(
    fontFamily: sans,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: Palette.ink,
  );

  static const display = TextStyle(
    fontFamily: mono,
    fontWeight: FontWeight.w400,
    color: Palette.ink,
  );
}
