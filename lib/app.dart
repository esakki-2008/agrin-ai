import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/farm_intelligence/farm_intelligence_page.dart';
import 'features/ai_advisory/ai_advisory_page.dart';
import 'features/crop_doctor/crop_doctor_page.dart';
import 'features/regenerative_farming/regenerative_farming_page.dart';
import 'features/historical_intelligence/historical_intelligence_page.dart';
import 'features/brics_network/brics_network_page.dart';
import 'theme/agri_n_design.dart';

class AgriNApp extends StatelessWidget {
  const AgriNApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
        GoRoute(path: '/farm-intelligence', builder: (context, state) => const FarmIntelligencePage()),
        GoRoute(path: '/ai-advisory', builder: (context, state) => const AiAdvisoryPage()),
        GoRoute(path: '/crop-doctor', builder: (context, state) => const CropDoctorPage()),
        GoRoute(path: '/regenerative-farming', builder: (context, state) => const RegenerativeFarmingPage()),
        GoRoute(path: '/historical-intelligence', builder: (context, state) => const HistoricalIntelligencePage()),
        GoRoute(path: '/brics-network', builder: (context, state) => const BricsNetworkPage()),
      ],
    );

    return MaterialApp.router(
      title: 'AgriN — Agricultural Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AgriNDesign.theme(),
      routerConfig: router,
      builder: (context, child) => AgriNCinematicLayer(child: child ?? const SizedBox.shrink()),
    );
  }
}
