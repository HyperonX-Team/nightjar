import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'features/calculator/calculator_screen.dart';
import 'theme/theme.dart';

/// Firebase is not initialized here. It starts only when setup or a trigger
/// needs it, so the calculator opens without a network path (SPEC 8.6).
class NightjarApp extends StatelessWidget {
  const NightjarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.visibleName,
      debugShowCheckedModeBanner: false,
      theme: buildNightjarTheme(),
      home: const CalculatorScreen(),
    );
  }
}
