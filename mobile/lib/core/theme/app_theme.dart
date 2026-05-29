import 'package:flutter/material.dart';

// Exact palette from the PWA's CSS variables
class AppColors {
  // Dark theme
  static const darkBg = Color(0xFF0C1A10);
  static const darkSurface = Color(0xFF111F15);
  static const darkCard = Color(0xFF18281C);
  static const darkBorder = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const darkText = Color(0xFFF0ECE3);
  static const darkMuted = Color(0xFF556358);

  // Light theme
  static const lightBg = Color(0xFFF7F4EC);
  static const lightSurface = Color(0xFFFFFAF0);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0x1F18281C); // rgba(24,40,28,0.12)
  static const lightText = Color(0xFF152018);
  static const lightMuted = Color(0xFF667268);

  // Shared accent colors
  static const accent = Color(0xFFC9A84C); // dark accent
  static const accentLight = Color(0xFF9F7B19); // light accent
  static const mint = Color(0xFF6DB87A);
  static const mintLight = Color(0xFF2F8A48);
  static const sky = Color(0xFF7DA8D4);
  static const skyLight = Color(0xFF3C76AD);
  static const peach = Color(0xFFD4886A);
  static const peachLight = Color(0xFFB85F3C);
  static const plum = Color(0xFFA882C4);
  static const plumLight = Color(0xFF8153A6);
  static const danger = Color(0xFFD46A5A);
  static const oai = Color(0xFF74AA9C);
}

class AppTheme {
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          background: AppColors.darkBg,
          surface: AppColors.darkSurface,
          primary: AppColors.accent,
          secondary: AppColors.mint,
          error: AppColors.danger,
          onBackground: AppColors.darkText,
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
            primary: AppColors.accent,
            onPrimary: AppColors.darkBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        extensions: const [AppColorsExtension.dark()],
      );

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: const ColorScheme.light(
          background: AppColors.lightBg,
          surface: AppColors.lightSurface,
          primary: AppColors.accentLight,
          secondary: AppColors.mintLight,
          error: AppColors.danger,
          onBackground: AppColors.lightText,
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
            primary: AppColors.accentLight,
            onPrimary: AppColors.lightBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        danger = AppColors.danger;

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
        danger = AppColors.danger;

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
    );
  }
}

// Convenience accessor
extension AppThemeContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
