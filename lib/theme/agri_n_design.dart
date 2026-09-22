import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AgriNDesign {
  static const ink = Color(0xFF11130F);
  static const paper = Color(0xFFF4F1E8);
  static const paper2 = Color(0xFFEAE6DA);
  static const green = Color(0xFF315D3B);
  static const line = Color(0x3311130F);
  static const muted = Color(0xFF66685F);

  static const _sans = 'Inter';
  static const _display = 'Cormorant Garamond';

  static TextStyle _sansStyle({
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) => TextStyle(
        fontFamily: _sans,
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle _displayStyle({
    double? fontSize,
    double? height,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) => TextStyle(
        fontFamily: _display,
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: _displayStyle(fontSize: 78, height: .88, fontWeight: FontWeight.w500, color: ink),
      displayMedium: _displayStyle(fontSize: 58, height: .92, fontWeight: FontWeight.w500, color: ink),
      headlineLarge: _displayStyle(fontSize: 42, height: .98, fontWeight: FontWeight.w500, color: ink),
      headlineMedium: _displayStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w500, color: ink),
      titleLarge: _sansStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: _sansStyle(fontSize: 15, height: 1.55, color: ink),
      bodyMedium: _sansStyle(fontSize: 13, height: 1.5, color: muted),
      labelSmall: _sansStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: muted),
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
        titleTextStyle: _sansStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        labelStyle: _sansStyle(fontSize: 12, color: muted),
        hintStyle: _sansStyle(fontSize: 12, color: muted),
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
          textStyle: _sansStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: ink),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: _sansStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                  style: _sansStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AgriNDesign.ink),
                ),
              ),
      ),
    );
  }
}


class AgriNCinematicLayer extends StatefulWidget {
  const AgriNCinematicLayer({super.key, required this.child});
  final Widget child;

  @override
  State<AgriNCinematicLayer> createState() => _AgriNCinematicLayerState();
}

class _AgriNCinematicLayerState extends State<AgriNCinematicLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .018),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(widget.child.key),
            child: widget.child,
          ),
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * 3.141592653589793;
              return Stack(
                children: [
                  Positioned(
                    left: -90 + 38 * math.sin(t),
                    top: 120 + 28 * math.cos(t * .7),
                    child: _ambientOrb(170, AgriNDesign.green.withValues(alpha: .045)),
                  ),
                  Positioned(
                    right: -100 + 42 * math.cos(t * .8),
                    bottom: 70 + 32 * math.sin(t * .6),
                    child: _ambientOrb(220, AgriNDesign.green.withValues(alpha: .035)),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CinematicLinePainter(progress: _controller.value),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SignalNetworkPainter(progress: _controller.value),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ambientOrb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 70,
              spreadRadius: 16,
            ),
          ],
        ),
      );
}

class _CinematicLinePainter extends CustomPainter {
  const _CinematicLinePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = AgriNDesign.ink.withValues(alpha: .055);

    final y = size.height * (.18 + .64 * progress);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), p);

    final x = size.width * (.82 - .12 * progress);
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _CinematicLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SignalNetworkPainter extends CustomPainter {
  const _SignalNetworkPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 520) return;

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = AgriNDesign.green.withValues(alpha: .075);

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = AgriNDesign.green.withValues(alpha: .11);

    final phase = progress * math.pi * 2;
    final points = <Offset>[
      Offset(size.width * .78, size.height * .20),
      Offset(size.width * .88, size.height * .34),
      Offset(size.width * .73, size.height * .48),
      Offset(size.width * .91, size.height * .63),
    ];

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], p);
    }

    for (var i = 0; i < points.length; i++) {
      final pulse = .75 + .25 * math.sin(phase + i);
      canvas.drawCircle(points[i], 3.5 * pulse, fill);
      canvas.drawCircle(points[i], 8 + 3 * pulse, p);
    }

    final sweepX = size.width * (.55 + .35 * ((math.sin(phase * .5) + 1) / 2));
    final sweep = Paint()
      ..strokeWidth = .6
      ..color = AgriNDesign.green.withValues(alpha: .035);
    canvas.drawLine(Offset(sweepX, 0), Offset(sweepX - 80, size.height), sweep);
  }

  @override
  bool shouldRepaint(covariant _SignalNetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
