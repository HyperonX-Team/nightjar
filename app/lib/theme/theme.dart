import 'package:flutter/material.dart';

import 'palette.dart';
import 'typography.dart';

/// Light theme only. A dark calculator would break the office-calculator
/// identity and a theme toggle would be a suspicious setting (DESIGN.md 25.8).
ThemeData buildNightjarTheme() {
  const scheme = ColorScheme.light(
    primary: Palette.oxide,
    onPrimary: Palette.paper,
    secondary: Palette.ink,
    onSecondary: Palette.paper,
    surface: Palette.paper,
    onSurface: Palette.ink,
    error: Palette.statusBad,
    onError: Palette.paper,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.paper,
    fontFamily: AppTypography.sans,
    textTheme: const TextTheme(
      titleMedium: AppTypography.title,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.secondary,
      labelLarge: AppTypography.button,
    ),
    iconTheme: const IconThemeData(color: Palette.ink, size: 20),
    dividerTheme: const DividerThemeData(
      color: Palette.rule,
      thickness: 1,
      space: 1,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.fuchsia: _NoTransitionsBuilder(),
      },
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.oxide,
        foregroundColor: Palette.paper,
        disabledBackgroundColor: Palette.keySurface,
        disabledForegroundColor: Palette.inkMuted,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppTypography.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.ink,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontFamily: AppTypography.sans,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      isDense: true,
      hintStyle: AppTypography.secondary,
      contentPadding: EdgeInsets.symmetric(vertical: 12),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Palette.rule),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Palette.rule),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Palette.ink, width: 2),
      ),
      errorStyle: TextStyle(
        fontFamily: AppTypography.sans,
        fontSize: 13,
        color: Palette.statusBad,
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Palette.paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: Palette.rule),
      ),
      titleTextStyle: AppTypography.title,
      contentTextStyle: AppTypography.body,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.ink,
      linearMinHeight: 2,
      linearTrackColor: Palette.keySurface,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.oxide
            : Palette.keySurface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.oxide.withValues(alpha: 0.35)
            : Palette.rule,
      ),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Motion is press states only, so routes appear without an entrance
/// animation (DESIGN.md).
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

/// The identity motif: a 1dp ink line under the display, the setup title,
/// and the contact page status (DESIGN.md).
class LedgerRule extends StatelessWidget {
  const LedgerRule({super.key, this.color = Palette.ink});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

enum SetupRowState { ok, warn, bad, pending }

class StatusMark extends StatelessWidget {
  const StatusMark(this.state, {super.key});

  final SetupRowState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      SetupRowState.ok => (Palette.statusOk, Icons.check_circle_outline),
      SetupRowState.warn => (Palette.statusWarn, Icons.warning_amber_rounded),
      SetupRowState.bad => (Palette.statusBad, Icons.error_outline),
      SetupRowState.pending => (Palette.inkMuted, Icons.remove_circle_outline),
    };
    return SizedBox(
      width: 24,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Scrollable setup screen: back control, title, ledger rule, content, actions.
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions = const <Widget>[],
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(title, style: AppTypography.title)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: LedgerRule(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final action in actions) ...[
                          action,
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the setup stack: status mark, label, short status, chevron.
class SetupRow extends StatelessWidget {
  const SetupRow({
    super.key,
    this.mark,
    required this.label,
    this.status,
    this.statusColor,
    this.onTap,
    this.trailing,
  });

  final SetupRowState? mark;
  final String label;
  final String? status;
  final Color? statusColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (mark != null) ...[
            StatusMark(mark!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.rowLabel),
                if (status != null)
                  Text(
                    status!,
                    style: AppTypography.secondary.copyWith(
                      color: statusColor ?? Palette.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            const Icon(Icons.chevron_right, size: 20, color: Palette.inkMuted),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onTap == null)
          row
        else
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: row,
          ),
        const LedgerRule(color: Palette.rule),
      ],
    );
  }
}
