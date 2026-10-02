import 'package:flutter/material.dart';

// Intimate Sanctuary palette from the Stitch design system.
const coral = Color(0xFF8F435F);
const rose = Color(0xFFF4E8EC);
const beige = Color(0xFFFAF8F6);
const slate = Color(0xFF28232B);
const mutedInk = Color(0xFF756C76);
const lavender = Color(0xFFEAE5F5);
const oat = Color(0xFFF5F1EE);
const hairline = Color(0xFFEFE9E4);
const apricot = Color(0xFFF6E6D9);

const editorial = TextStyle(
    fontFamily: 'Newsreader',
    fontFamilyFallback: ['serif'],
    fontWeight: FontWeight.w500,
    color: slate,
    letterSpacing: -.7);

ThemeData nearTheme() {
  const font = 'Plus Jakarta Sans';
  const display = 'Newsreader';
  return ThemeData(
    useMaterial3: true,
    fontFamily: font,
    fontFamilyFallback: const ['Apple Color Emoji'],
    scaffoldBackgroundColor: beige,
    colorScheme: ColorScheme.fromSeed(
        seedColor: coral, primary: coral, surface: beige, onSurface: slate),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
          fontFamily: display,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: slate,
          letterSpacing: -1.2,
          height: 1.15),
      headlineSmall: TextStyle(
          fontFamily: display,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: slate,
          letterSpacing: -.7,
          height: 1.25),
      titleLarge: TextStyle(
          fontFamily: font,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: slate,
          letterSpacing: -.4),
      bodyLarge: TextStyle(
          fontFamily: font,
          fontSize: 16,
          color: slate,
          height: 1.45,
          letterSpacing: -.2),
      bodyMedium:
          TextStyle(fontFamily: font, fontSize: 14, color: slate, height: 1.45),
      bodySmall: TextStyle(
          fontFamily: font, fontSize: 12, color: mutedInk, height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
        backgroundColor: beige,
        foregroundColor: slate,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true),
    navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: rose,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(TextStyle(
            fontFamily: font, fontSize: 11, fontWeight: FontWeight.w600))),
    cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: hairline),
            borderRadius: BorderRadius.circular(24))),
    dividerTheme:
        const DividerThemeData(color: hairline, space: 24, thickness: 1),
    chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: oat,
        selectedColor: rose,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: oat,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none)),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 50),
            textStyle: TextStyle(
                fontFamily: font, fontWeight: FontWeight.w600, fontSize: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFDED8D3)),
            minimumSize: const Size(44, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: beige, showDragHandle: true),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: rose,
        foregroundColor: coral,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  );
}

class CozyCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const CozyCard({super.key, required this.child, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: hairline, width: .8),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A28232B),
                  blurRadius: 10,
                  offset: Offset(0, 2)),
            ]),
        child: Material(type: MaterialType.transparency, child: child),
      );
}
