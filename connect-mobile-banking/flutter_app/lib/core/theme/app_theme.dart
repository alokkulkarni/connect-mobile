import 'package:flutter/material.dart';

import 'tokens.dart';

// Material 3 themes built from the web app's tokens: navy headers and buttons, soft blue-grey pages, white cards.
ThemeData bankTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? BankColors.light : BankColors.dark;
  final scheme = ColorScheme.fromSeed(seedColor: c.brand, brightness: brightness).copyWith(
    primary: brightness == Brightness.light ? c.brand : c.brand2,
    onPrimary: Colors.white,
    secondary: c.brand2,
    surface: c.card,
    onSurface: c.ink,
    error: c.moneyOut,
    outlineVariant: c.line,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(BankColors.radius));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape.copyWith(side: BorderSide(color: c.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: c.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.brand2.withValues(alpha: 0.14),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, color: c.ink, fontWeight: FontWeight.w600)),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.line)),
    ),
    chipTheme: ChipThemeData(shape: StadiumBorder(side: BorderSide(color: c.line))),
  );
}
