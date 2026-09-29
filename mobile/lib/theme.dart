import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

const coral = Color(0xFF965468);
const rose = Color(0xFFF0E4E7);
const beige = Color(0xFFF7F6F3);
const slate = Color(0xFF292D35);

ThemeData nearTheme() {
  final apple = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  final font = apple ? 'CupertinoSystemText' : 'Inter';
  final display = apple ? 'CupertinoSystemDisplay' : 'Inter';
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
          fontWeight: FontWeight.w700,
          color: slate,
          letterSpacing: -1.2,
          height: 1.15),
      headlineSmall: TextStyle(
          fontFamily: display,
          fontSize: 25,
          fontWeight: FontWeight.w600,
          color: slate,
          letterSpacing: -.7,
          height: 1.25),
      titleLarge: TextStyle(
          fontFamily: display,
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
          fontFamily: font,
          fontSize: 12,
          color: const Color(0xFF777880),
          height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
        backgroundColor: beige,
        foregroundColor: slate,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true),
    navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: rose,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(TextStyle(
            fontFamily: font, fontSize: 10, fontWeight: FontWeight.w500))),
    cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    dividerTheme: const DividerThemeData(
        color: Color(0xFFEAE7E5), space: 24, thickness: 1),
    chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: const Color(0xFFEFEDEB),
        selectedColor: rose,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0EFED),
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
            side: const BorderSide(color: Color(0xFFDED8D7)),
            minimumSize: const Size(44, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: beige, showDragHandle: true),
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
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFEDEAE7), width: .7)),
        child: Material(type: MaterialType.transparency, child: child),
      );
}
