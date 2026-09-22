import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgriNDesign {
  static const ink = Color(0xFF11130F);
  static const paper = Color(0xFFF4F1E8);
  static const paper2 = Color(0xFFEAE6DA);
  static const green = Color(0xFF315D3B);
  static const line = Color(0x3311130F);
  static const muted = Color(0xFF66685F);

  static TextTheme textTheme() {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.cormorantGaramond(fontSize: 78, height: .88, fontWeight: FontWeight.w500, color: ink),
      displayMedium: GoogleFonts.cormorantGaramond(fontSize: 58, height: .92, fontWeight: FontWeight.w500, color: ink),
      headlineLarge: GoogleFonts.cormorantGaramond(fontSize: 42, height: .98, fontWeight: FontWeight.w500, color: ink),
      headlineMedium: GoogleFonts.cormorantGaramond(fontSize: 32, height: 1.0, fontWeight: FontWeight.w500, color: ink),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: GoogleFonts.inter(fontSize: 15, height: 1.55, color: ink),
      bodyMedium: GoogleFonts.inter(fontSize: 13, height: 1.5, color: muted),
      labelSmall: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: muted),
    );
  }

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
      surface: paper,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: green, onPrimary: Colors.white, surface: paper),
      scaffoldBackgroundColor: paper,
      textTheme: textTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: muted),
        hintStyle: GoogleFonts.inter(fontSize: 12, color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: const OutlineInputBorder(borderSide: BorderSide(color: line)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: line)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: green, width: 1.4)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: ink),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: line),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class EditorialRule extends StatelessWidget {
  const EditorialRule({super.key, this.margin = EdgeInsets.zero});
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: const Divider(height: 1, thickness: 1, color: AgriNDesign.line),
  );
}

class MotionOrb extends StatelessWidget {
  const MotionOrb({super.key, required this.size, this.label});
  final double size;
  final String? label;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.scale(
        scale: .82 + value * .18,
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AgriNDesign.paper2,
          border: Border.all(color: AgriNDesign.ink.withValues(alpha: .65)),
        ),
        child: label == null
            ? null
            : Center(
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AgriNDesign.ink),
                ),
              ),
      ),
    );
  }
}
