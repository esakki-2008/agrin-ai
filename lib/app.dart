import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/farm_intelligence/farm_intelligence_page.dart';

class AgriNApp extends StatelessWidget {
  const AgriNApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/farm-intelligence', builder: (context, state) => const FarmIntelligencePage()),
      ],
    );

    return MaterialApp.router(
      title: 'AgriN AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7D4C)),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      routerConfig: router,
    );
  }
}
