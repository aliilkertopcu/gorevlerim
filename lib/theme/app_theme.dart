import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — Material 3, seeded at runtime by the selected group's color.
///
/// Rules of the house:
/// - Colors come from [ColorScheme] roles (or [statusColor]/[statusBackground]),
///   never raw hex in widgets.
/// - Corners come from [Corners] (small 8 / medium 12 / large 16, buttons full).
/// - Spacing comes from [Gap] (4/8 rhythm).
/// - Text styles come from Theme.of(context).textTheme (Plus Jakarta Sans).
class AppTheme {
  /// Default seed (also the historical brand color). Personal groups created
  /// from 2026-08-31 on default to teal; existing groups keep their color.
  static const Color primaryColor = Color(0xFF667eea);
  static const Color tealSeed = Color(0xFF0D9488);

  // Status hues (identity constants — tonal variants are derived per theme).
  static const Color completedColor = Color(0xFF2E9E5B);
  static const Color blockedColor = Color(0xFFD64545);
  static const Color postponedColor = Color(0xFFE8890C);
  static const Color pendingColor = Color(0xFFC7A500);

  static ThemeData lightTheme([Color seed = primaryColor]) => _theme(seed, Brightness.light);
  static ThemeData darkTheme([Color seed = primaryColor]) => _theme(seed, Brightness.dark);

  static ThemeData _theme(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final baseText = brightness == Brightness.light
        ? Typography.blackMountainView
        : Typography.whiteMountainView;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseText);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: Corners.small,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.small,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.small,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.sm2, vertical: Gap.sm2),
        filled: brightness == Brightness.dark,
        fillColor: brightness == Brightness.dark ? scheme.surfaceContainerLow : null,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(borderRadius: Corners.medium),
        elevation: 3,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(borderRadius: Corners.large),
        elevation: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: Corners.small),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }

  /// Foreground hue for a task status (border stripe, badges, icons).
  /// Slightly brightened in dark mode so it holds ≥3:1 against dark surfaces.
  static Color statusColor(String status, {Brightness brightness = Brightness.light}) {
    final base = switch (status) {
      'completed' => completedColor,
      'blocked' => blockedColor,
      'postponed' => postponedColor,
      _ => pendingColor,
    };
    if (brightness == Brightness.dark) {
      final h = HSLColor.fromColor(base);
      return h.withLightness((h.lightness + 0.18).clamp(0.0, 1.0)).toColor();
    }
    return base;
  }

  /// Card surface tinted toward the status hue — derived from the active
  /// scheme, so light/dark contrast stays correct automatically.
  static Color statusBackground(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    if (status == 'pending') return scheme.surfaceContainerLow;
    final hue = statusColor(status, brightness: scheme.brightness);
    final alpha = scheme.brightness == Brightness.dark ? 0.16 : 0.10;
    return Color.alphaBlend(hue.withValues(alpha: alpha), scheme.surfaceContainerLow);
  }
}

/// Corner radius tokens (MD3: small=fields/chips, medium=cards, large=dialogs).
abstract final class Corners {
  static const small = BorderRadius.all(Radius.circular(8));
  static const medium = BorderRadius.all(Radius.circular(12));
  static const large = BorderRadius.all(Radius.circular(16));
  static const rSmall = Radius.circular(8);
  static const rMedium = Radius.circular(12);
  static const rLarge = Radius.circular(16);
}

/// Spacing rhythm (4/8 dp system).
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double sm2 = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
