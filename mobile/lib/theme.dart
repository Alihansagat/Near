import 'package:flutter/material.dart';

const coral = Color(0xFFA94762);
const rose = Color(0xFFF2DFE2);
const beige = Color(0xFFFBF8F5);
const slate = Color(0xFF39343C);

ThemeData nearTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: beige,
      colorScheme: ColorScheme.fromSeed(
          seedColor: coral, primary: coral, surface: beige),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: slate,
            letterSpacing: -1),
        headlineSmall:
            TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: slate),
        titleLarge:
            TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: slate),
        bodyLarge: TextStyle(fontSize: 16, color: slate, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: slate, height: 1.5),
      ),
      appBarTheme: const AppBarTheme(
          backgroundColor: beige, foregroundColor: slate, elevation: 0),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: rose,
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
      chipTheme: ChipThemeData(
          side: BorderSide.none,
          backgroundColor: beige,
          selectedColor: rose,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      )),
    );

class CozyCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const CozyCard({super.key, required this.child, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: rose.withValues(alpha: .5))),
        child: Material(type: MaterialType.transparency, child: child),
      );
}
