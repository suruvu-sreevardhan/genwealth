import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2563EB);
  static const Color mint = Color(0xFF14B8A6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color background = Color(0xFFF8FAFC);
  static const Color dark = Color(0xFF0F172A);
  static const Color cardWhite = Color(0xFFFFFFFF);

  static const double _radius = 16;

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: mint,
      onSecondary: Colors.white,
      tertiary: purple,
      onTertiary: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: dark,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      textTheme: _textTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: dark,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: dark,
          letterSpacing: 0.1,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary.withOpacity(0.45);
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: primary.withOpacity(0.28)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardWhite,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dark.withOpacity(0.04), width: 1),
        ),
        shadowColor: dark.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedItemColor: primary,
        unselectedItemColor: dark.withOpacity(0.35),
        showUnselectedLabels: true,
        backgroundColor: cardWhite,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.86),
        indicatorColor: primary.withOpacity(0.14),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : dark.withOpacity(0.55),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : dark.withOpacity(0.5),
            size: 24,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: dark.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: dark.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
        ),
        hintStyle: TextStyle(color: dark.withOpacity(0.42), fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: dark.withOpacity(0.65), fontWeight: FontWeight.w500),
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: dark.withOpacity(0.07),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      extensions: const [
        AppGlassTheme.light,
      ],
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: mint,
      tertiary: purple,
      surface: const Color(0xFF111A2B),
      onSurface: const Color(0xFFE5E7EB),
      error: const Color(0xFFF87171),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: dark,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return base.copyWith(
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary.withOpacity(0.5);
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF162238),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.black.withOpacity(0.4),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFF17243D).withOpacity(0.88),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF17243D).withOpacity(0.88),
        indicatorColor: primary.withOpacity(0.28),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : Colors.white70,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF17243D),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: mint, width: 1.4),
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500),
      ),
      extensions: [
        AppGlassTheme.dark,
      ],
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bodyColor = isDark ? const Color(0xFFE2E8F0) : dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return TextTheme(
      displayLarge: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -0.9, color: bodyColor),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: bodyColor),
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: bodyColor),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: bodyColor),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.15, color: bodyColor),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: bodyColor),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: bodyColor),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: bodyColor),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: muted),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: bodyColor),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
    );
  }
}

@immutable
class AppGlassTheme extends ThemeExtension<AppGlassTheme> {
  final Color color;
  final double blurSigma;
  final Border border;
  final List<BoxShadow> shadow;

  const AppGlassTheme({
    required this.color,
    required this.blurSigma,
    required this.border,
    required this.shadow,
  });

  static const light = AppGlassTheme(
    color: Color(0xFFFFFFFF),
    blurSigma: 0,
    border: Border.fromBorderSide(
      BorderSide(color: Color(0x0A0F172A), width: 1.0),
    ),
    shadow: [
      BoxShadow(
        color: Color(0x0A0F172A),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  );

  static AppGlassTheme get dark {
    final useBlur = kIsWeb;
    return AppGlassTheme(
      color: const Color(0x331E293B),
      blurSigma: useBlur ? 22 : 0,
      border: const Border.fromBorderSide(
        BorderSide(color: Color(0x40FFFFFF), width: 1.0),
      ),
      shadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  @override
  AppGlassTheme copyWith({
    Color? color,
    double? blurSigma,
    Border? border,
    List<BoxShadow>? shadow,
  }) {
    return AppGlassTheme(
      color: color ?? this.color,
      blurSigma: blurSigma ?? this.blurSigma,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppGlassTheme lerp(ThemeExtension<AppGlassTheme>? other, double t) {
    if (other is! AppGlassTheme) {
      return this;
    }

    return AppGlassTheme(
      color: Color.lerp(color, other.color, t) ?? color,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
      border: Border.lerp(border, other.border, t) ?? border,
      shadow: BoxShadow.lerpList(shadow, other.shadow, t) ?? shadow,
    );
  }
}
