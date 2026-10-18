import 'package:flutter/material.dart';

/// Palette from DESIGN.md. Four values: paper, ink, key surface, oxide.
class Palette {
  static const paper = Color(0xFFE9E5DB);
  static const ink = Color(0xFF1C1B18);
  static const keySurface = Color(0xFFD9D3C6);
  static const oxide = Color(0xFF9C3D2E);

  /// Ink at 72 percent over paper, flattened so its contrast is fixed at 6.0:1.
  static const inkMuted = Color(0xFF55534A);

  /// One step darker than key surface, for the 1px press depression.
  static const keyPressed = Color(0xFFCFC9BC);

  /// Key outline: ink at 35 percent over key surface. Decorative, not text.
  static const keyOutline = Color(0xFF979389);

  /// Status colors carry permission and test results only (SPEC 23.3, 23.5, 34).
  /// Each passes 4.5:1 on paper; verified in test/contrast_test.dart.
  static const statusOk = Color(0xFF2F5D3A);
  static const statusWarn = Color(0xFF8A5A12);
  static const statusBad = Color(0xFFA02B20);

  /// Hairline used by the ledger rule and row separators.
  static const rule = Color(0xFFB9B2A4);
}
