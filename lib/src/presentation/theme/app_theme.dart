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
    canvas: Color(0xFF0B0C0F),
    surface: Color(0xFF121318),
    surfaceAlt: Color(0xFF161820),
    border: Color(0x16FFFFFF),
    subtle: Color(0xFF8A8F98),
    text: Color(0xFFE7E9ED),
    accent: Color(0xFF58C1FF),
    overlay: Color(0xCC000000),
  );

  static const AppThemeColors lightColors = AppThemeColors(
    canvas: Color(0xFFF4F6FA),
    surface: Color(0xFFE6EBF3),
    surfaceAlt: Color(0xFFDCE3EE),
    border: Color(0x1A000000),
    subtle: Color(0xFF68707D),
    text: Color(0xFF101318),
    accent: Color(0xFF1B84D8),
    overlay: Color(0x66000000),
  );

  static ThemeData darkTheme({required PageTransitionsTheme transitions}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: darkColors.accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkColors.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: darkColors.surface,
        foregroundColor: darkColors.text,
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
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightColors.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: lightColors.surface,
        foregroundColor: lightColors.text,
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
