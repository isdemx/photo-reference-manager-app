import 'package:flutter/material.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color subtle;
  final Color accent;
  final Color overlay;

  const AppThemeColors({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.subtle,
    required this.accent,
    required this.overlay,
  });

  @override
  AppThemeColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? subtle,
    Color? accent,
    Color? overlay,
  }) {
    return AppThemeColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      subtle: subtle ?? this.subtle,
      accent: accent ?? this.accent,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      text: Color.lerp(text, other.text, t) ?? text,
      subtle: Color.lerp(subtle, other.subtle, t) ?? subtle,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      overlay: Color.lerp(overlay, other.overlay, t) ?? overlay,
    );
  }
}

class AppThemes {
  static const AppThemeColors darkColors = AppThemeColors(
    canvas: Color(0xFF0C0D10),
    surface: Color(0xFF13141A),
    surfaceAlt: Color(0xFF171A22),
    border: Color(0x16FFFFFF),
    subtle: Color(0xFF6E6B66),
    text: Color(0xFFBBB8B3),
    accent: Color(0xFF58C1FF),
    overlay: Color(0xCC000000),
  );

  static const AppThemeColors lightColors = AppThemeColors(
    canvas: Color(0xFFE6E9EC),
    surface: Color(0xFFD7DCE0),
    surfaceAlt: Color(0xFFC8D0D6),
    border: Color(0x22000000),
    subtle: Color(0xFF5A554F),
    text: Color(0xFF46413A),
    accent: Color(0xFF5B7686),
    overlay: Color(0x66000000),
  );

  static ThemeData darkTheme({required PageTransitionsTheme transitions}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: darkColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: darkColors.surface,
      onSurface: darkColors.text,
      outline: darkColors.border,
      primary: darkColors.accent,
      surfaceContainer: darkColors.surface,
      surfaceContainerHigh: darkColors.surfaceAlt,
      surfaceContainerHighest: darkColors.surfaceAlt,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkColors.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: darkColors.surface,
        foregroundColor: darkColors.text,
        titleTextStyle: const TextStyle(
          color: Color(0xFF6E6B66),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkColors.surface,
        titleTextStyle: TextStyle(
          color: darkColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: darkColors.subtle,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: darkColors.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: darkColors.border),
      listTileTheme: ListTileThemeData(
        iconColor: darkColors.subtle,
        textColor: darkColors.text,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: darkColors.text,
        displayColor: darkColors.text,
      ),
      pageTransitionsTheme: transitions,
      extensions: const <ThemeExtension<dynamic>>[
        darkColors,
      ],
    );
  }

  static ThemeData lightTheme({required PageTransitionsTheme transitions}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: lightColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      surface: lightColors.surface,
      onSurface: lightColors.text,
      outline: lightColors.border,
      primary: lightColors.accent,
      onPrimary: Colors.white,
      surfaceContainer: lightColors.surface,
      surfaceContainerHigh: lightColors.surfaceAlt,
      surfaceContainerHighest: lightColors.surfaceAlt,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightColors.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: lightColors.surface,
        foregroundColor: lightColors.text,
        titleTextStyle: const TextStyle(
          color: Color(0xFF676058),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightColors.surface,
        titleTextStyle: TextStyle(
          color: lightColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: lightColors.subtle,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: lightColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: lightColors.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: lightColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: lightColors.border),
      listTileTheme: ListTileThemeData(
        iconColor: lightColors.subtle,
        textColor: lightColors.text,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: lightColors.text,
        displayColor: lightColors.text,
      ),
      pageTransitionsTheme: transitions,
      extensions: const <ThemeExtension<dynamic>>[
        lightColors,
      ],
    );
  }
}

extension AppThemeColorsX on BuildContext {
  AppThemeColors get appThemeColors {
    return Theme.of(this).extension<AppThemeColors>() ?? AppThemes.darkColors;
  }
}
