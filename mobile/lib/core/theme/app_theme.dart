import 'package:flutter/material.dart';

class AppColors {
  // Dark theme
  static const darkBg = Color(0xFF0C1A10);
  static const darkSurface = Color(0xFF132018);
  static const darkCard = Color(0xFF1C2C22);
  static const darkBorder = Color(0x4DFFFFFF); // rgba(255,255,255,0.30)
  static const darkText = Color(0xFFFFF8EC);
  static const darkMuted = Color(0xFFB8C4BA);

  // Light theme
  static const lightBg = Color(0xFFF7F4EC);
  static const lightSurface = Color(0xFFFFFAF0);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0x1F18281C); // rgba(24,40,28,0.12)
  static const lightText = Color(0xFF152018);
  static const lightMuted = Color(0xFF667268);

  // Shared accent colors
  static const accent = Color(0xFFE6C65C); // dark accent
  static const accentLight = Color(0xFF9F7B19); // light accent
  static const mint = Color(0xFF82D894);
  static const mintLight = Color(0xFF2F8A48);
  static const sky = Color(0xFF9DCAFA);
  static const skyLight = Color(0xFF3C76AD);
  static const peach = Color(0xFFF2A17D);
  static const peachLight = Color(0xFFB85F3C);
  static const plum = Color(0xFFCEA5F2);
  static const plumLight = Color(0xFF8153A6);
  static const danger = Color(0xFFFF8A78);
  static const oai = Color(0xFF8AD4C4);
}

class AppTheme {
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.darkSurface,
          primary: AppColors.accent,
          secondary: AppColors.mint,
          error: AppColors.danger,
          onSurface: AppColors.darkText,
          onPrimary: AppColors.darkBg,
        ),
        cardColor: AppColors.darkCard,
        dividerColor: AppColors.darkBorder,
        fontFamily: 'DM Sans',
        textTheme: _textTheme(AppColors.darkText, AppColors.darkMuted),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkText,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.darkMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
          labelStyle: const TextStyle(color: AppColors.darkMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.darkBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        extensions: const [AppColorsExtension.dark()],
      );

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: const ColorScheme.light(
          surface: AppColors.lightSurface,
          primary: AppColors.accentLight,
          secondary: AppColors.mintLight,
          error: AppColors.danger,
          onSurface: AppColors.lightText,
          onPrimary: AppColors.lightBg,
        ),
        cardColor: AppColors.lightCard,
        dividerColor: AppColors.lightBorder,
        fontFamily: 'DM Sans',
        textTheme: _textTheme(AppColors.lightText, AppColors.lightMuted),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.lightText,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightSurface,
          selectedItemColor: AppColors.accentLight,
          unselectedItemColor: AppColors.lightMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentLight),
          ),
          labelStyle: const TextStyle(color: AppColors.lightMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentLight,
            foregroundColor: AppColors.lightBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        extensions: const [AppColorsExtension.light()],
      );

  static TextTheme _textTheme(Color primary, Color muted) => TextTheme(
        displayLarge: TextStyle(color: primary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: primary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: primary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: primary, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: primary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: primary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: primary),
        bodyLarge: TextStyle(color: primary),
        bodyMedium: TextStyle(color: primary),
        bodySmall: TextStyle(color: muted),
        labelLarge: TextStyle(color: primary, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: muted),
      );
}

// Extension so widgets can access semantic colors
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color bg;
  final Color surface;
  final Color card;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final Color mint;
  final Color sky;
  final Color peach;
  final Color plum;
  final Color danger;
  final Color oai;

  const AppColorsExtension({
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.mint,
    required this.sky,
    required this.peach,
    required this.plum,
    required this.danger,
    required this.oai,
  });

  const AppColorsExtension.dark()
      : bg = AppColors.darkBg,
        surface = AppColors.darkSurface,
        card = AppColors.darkCard,
        border = AppColors.darkBorder,
        text = AppColors.darkText,
        muted = AppColors.darkMuted,
        accent = AppColors.accent,
        mint = AppColors.mint,
        sky = AppColors.sky,
        peach = AppColors.peach,
        plum = AppColors.plum,
        danger = AppColors.danger,
        oai = AppColors.oai;

  const AppColorsExtension.light()
      : bg = AppColors.lightBg,
        surface = AppColors.lightSurface,
        card = AppColors.lightCard,
        border = AppColors.lightBorder,
        text = AppColors.lightText,
        muted = AppColors.lightMuted,
        accent = AppColors.accentLight,
        mint = AppColors.mintLight,
        sky = AppColors.skyLight,
        peach = AppColors.peachLight,
        plum = AppColors.plumLight,
        danger = AppColors.danger,
        oai = AppColors.oai;

  @override
  AppColorsExtension copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? border,
    Color? text,
    Color? muted,
    Color? accent,
    Color? mint,
    Color? sky,
    Color? peach,
    Color? plum,
    Color? danger,
    Color? oai,
  }) =>
      AppColorsExtension(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        border: border ?? this.border,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        mint: mint ?? this.mint,
        sky: sky ?? this.sky,
        peach: peach ?? this.peach,
        plum: plum ?? this.plum,
        danger: danger ?? this.danger,
        oai: oai ?? this.oai,
      );

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      peach: Color.lerp(peach, other.peach, t)!,
      plum: Color.lerp(plum, other.plum, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      oai: Color.lerp(oai, other.oai, t)!,
    );
  }
}

// Convenience accessor
extension AppThemeContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
