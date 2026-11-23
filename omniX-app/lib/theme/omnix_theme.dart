import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OmniXTokens {
  // Token dari design system "music streaming app dark premium"
  // (ui-ux-pro-max --design-system): Dark Mode OLED.
  static const Color darkCanvas = Color(0xFF0F0F23);
  static const Color darkSurface = Color(0xFF1B1B30);
  static const Color darkSurfaceElevated = Color(0xFF23233F);
  static const Color darkBorder = Color(0xFF312E81);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkAccent = Color(0xFF4338CA);
  static const Color darkAccentBright = Color(0xFF818CF8);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color dangerRed = Color(0xFFFF5C5C);

  static const Color lightCanvas = Color(0xFFF6F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFECECF6);
  static const Color lightBorder = Color(0xFFD0D0E0);
  static const Color lightTextPrimary = Color(0xFF111118);
  static const Color lightTextSecondary = Color(0xFF48485A);
  static const Color lightAccent = Color(0xFF4338CA);
  static const Color lightDanger = Color(0xFFC81E1E);
  static const Color lightSuccessText = Color(0xFF157347);
  static const Color lightWarning = Color(0xFF92400E);
  static const Color lightBorderInput = Color(0xFF4338CA);

  // Token peran tambahan (replica-design Tahap 1, tokens.json adalah sumber
  // kebenaran). accent #4338CA HANYA isian — teks/ikon aksen di atas latar
  // gelap memakai darkAccentBright (6,33:1, lolos AA); accent sebagai teks
  // hanya 2,39:1 dan dilarang. Ikon tombol Putar hijau memakai warna GELAP
  // di atas hijau (putih hanya 2,28:1, gagal).
  static const Color darkBorderInput = Color(0xFF818CF8);
  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkOnSuccess = Color(0xFF0F0F23);
  static const Color darkOnDanger = Color(0xFF0F0F23);
  static const Color playGreen = Color(0xFF22C55E);
  static const Color onPlay = Color(0xFF0F0F23);

  // Resep Liquid Glass (design.md §3 + LiquidGlassBox). Hanya 3 tingkat.
  static const double glassBlur = 24.0;
  static const double glassBlurSmall = 16.0;
  static const double glassSaturation = 1.8;
  static const double glassFill1 = 0.12;
  static const double glassFill2 = 0.16;
  static const double glassFill3 = 0.18;
  static const double glassFillLight = 0.86;
  static const double glassBorder1 = 0.25;
  static const double glassBorder2 = 0.20;
  static const double glassBorder3 = 0.30;
  static const double glassShadowAlphaDark = 0.32;
  static const double glassShadowAlphaLight = 0.12;

  // Durasi motion (animasi-per-fitur.md §10.1). Satu durasi per konteks —
  // jangan satu durasi untuk semua transisi.
  static const Duration motionInstant = Duration(milliseconds: 100);
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 200);
  static const Duration motionStandard = Duration(milliseconds: 250);
  static const Duration motionMedium = Duration(milliseconds: 300);
  static const Duration motionSlow = Duration(milliseconds: 350);
  static const Duration motionAccent = Duration(milliseconds: 600);
  static const Duration skeletonCycle = Duration(milliseconds: 1200);
  static const double marqueeSpeedPxPerSecond = 30.0;

  // Skala tipografi snap (12/14/16/20/28/40). Pemetaan gaya design.md:
  // micro 11→xs, caption 13→sm, body 15→base, heading 17→base semibold,
  // title 22→lg, display 28→xl.
  static const double typeXs = 12.0;
  static const double typeSm = 14.0;
  static const double typeBase = 16.0;
  static const double typeLg = 20.0;
  static const double typeXl = 28.0;
  static const double typeDisplay = 40.0;

  // Spacing — satuan dasar 4px, hanya kelipatan ini.
  static const List<double> spaceScale = [
    0, 4, 8, 12, 16, 20, 24, 32, 40, 48,
  ];

  // Radius artwork 4px sesuai preview UI v2 (dulu 12px).
  static const double radiusThumb = 4.0;
  static const double radiusInput = 16.0;
  static const double radiusCard = 20.0;
  // Mini player & sheet bawah 16px sesuai preview UI v2 (dulu 24px).
  static const double radiusMiniPlayer = 16.0;
  static const double radiusNavbar = 32.0;
  static const double radiusPill = 999.0;

  static const double minTouchTarget = 48.0;

  static const double breakpointTablet = 640.0;
  static const double breakpointDesktop = 1024.0;

  // Breakpoint design.md §9.3 (token). breakpointTablet/Desktop di atas
  // adalah nilai legacy yang masih dipakai kode — selaraskan ke token ini
  // saat build (M0): ponsel <600, tablet 600–899, desktop ≥900, lebar ≥1200.
  static const double breakpointPhone = 600.0;
  static const double breakpointWide = 900.0;
  static const double breakpointXWide = 1200.0;
}

class OmniXTheme {
  static ThemeData dark() {
    return _buildTheme(
      brightness: Brightness.dark,
      canvas: OmniXTokens.darkCanvas,
      surface: OmniXTokens.darkSurface,
      surfaceElevated: OmniXTokens.darkSurfaceElevated,
      border: OmniXTokens.darkBorder,
      textPrimary: OmniXTokens.darkTextPrimary,
      textSecondary: OmniXTokens.darkTextSecondary,
      accent: OmniXTokens.darkAccent,
      onAccent: Colors.white,
      focusRing: OmniXTokens.darkAccentBright,
      borderInput: OmniXTokens.darkBorderInput,
      errorColor: OmniXTokens.dangerRed,
    );
  }

  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      canvas: OmniXTokens.lightCanvas,
      surface: OmniXTokens.lightSurface,
      surfaceElevated: OmniXTokens.lightSurfaceElevated,
      border: OmniXTokens.lightBorder,
      textPrimary: OmniXTokens.lightTextPrimary,
      textSecondary: OmniXTokens.lightTextSecondary,
      accent: OmniXTokens.lightAccent,
      onAccent: Colors.white,
      focusRing: OmniXTokens.lightAccent,
      borderInput: OmniXTokens.lightBorderInput,
      errorColor: const Color(0xFFC81E1E),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color surfaceElevated,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color onAccent,
    required Color focusRing,
    // Token border-input (replica-design Tahap 3): border input lama
    // #312E81 hanya 1,65:1 vs bg dan gagal 3:1 (WCAG 1.4.11); token ini
    // 6,32:1 (gelap) / 7,36:1 (terang).
    required Color borderInput,
    required Color errorColor,
  }) {
    final baseScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: OmniXTokens.successGreen,
      onSecondary: OmniXTokens.darkCanvas,
      tertiary: focusRing,
      error: errorColor,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      surfaceContainerHighest: surfaceElevated,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      colorScheme: baseScheme,
      focusColor: focusRing.withValues(alpha: 0.28),
      hoverColor: textPrimary.withValues(alpha: 0.06),
      splashColor: accent.withValues(alpha: 0.14),
      dividerColor: border,
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.2,
          ),
          titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.25,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          bodyLarge: TextStyle(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            color: textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          labelLarge: TextStyle(
            color: textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
          borderSide: BorderSide(color: borderInput, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
          borderSide: BorderSide(color: focusRing, width: 2),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(OmniXTokens.minTouchTarget, OmniXTokens.minTouchTarget),
          ),
          mouseCursor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return SystemMouseCursors.forbidden;
            }
            return SystemMouseCursors.click;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: focusRing, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(OmniXTokens.minTouchTarget, OmniXTokens.minTouchTarget),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return surfaceElevated;
            }
            return accent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return textSecondary;
            }
            return onAccent;
          }),
          mouseCursor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return SystemMouseCursors.forbidden;
            }
            return SystemMouseCursors.click;
          }),
          shape: WidgetStateProperty.resolveWith((states) {
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OmniXTokens.radiusInput),
              side: states.contains(WidgetState.focused)
                  ? BorderSide(color: textPrimary, width: 2)
                  : BorderSide.none,
            );
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(OmniXTokens.minTouchTarget, OmniXTokens.minTouchTarget),
          ),
          foregroundColor: WidgetStatePropertyAll(textPrimary),
          mouseCursor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return SystemMouseCursors.forbidden;
            }
            return SystemMouseCursors.click;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: focusRing, width: 2);
            }
            return BorderSide(color: border, width: 1);
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OmniXTokens.radiusInput),
            ),
          ),
        ),
      ),
    );
  }
}
