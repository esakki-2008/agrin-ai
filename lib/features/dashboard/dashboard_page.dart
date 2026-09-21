import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const green = Color(0xFF2E6B43);
  static const dark = Color(0xFF102318);
  static const muted = Color(0xFF66736A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _nav(wide),
                        const SizedBox(height: 32),
                        _hero(context, wide),
                        const SizedBox(height: 24),
                        _metrics(wide),
                        const SizedBox(height: 24),
                        _intelligenceGrid(wide),
                        const SizedBox(height: 24),
                        _bricsBanner(context, wide),
                        const SizedBox(height: 36),
                        const Center(child: Text('AgriN AI • Built for resilient farming across India and beyond', style: TextStyle(color: muted, fontSize: 12))),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _nav(bool wide) {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 25),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(width: 12),
        const Text('AgriN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: dark)),
        const Text(' AI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: green)),
        const Spacer(),
        if (wide) ...[
          _navItem('Dashboard', true),
          _navItem('Farm Intelligence', false),
          _navItem('Crop Doctor', false),
          InkWell(onTap: () => GoRouter.of(context).push('/brics-network'), child: _navItem('BRICS Network', false)),
          const SizedBox(width: 20),
        ],
        IconButton(onPressed: () {}, icon: const Icon(Icons.language_rounded)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFFE8F1E9), borderRadius: BorderRadius.circular(14)),
          child: const Row(children: [Icon(Icons.location_on_outlined, size: 17, color: green), SizedBox(width: 5), Text('India', style: TextStyle(fontWeight: FontWeight.w600))]),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -.12, end: 0);
  }

  Widget _navItem(String label, bool active) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 11),
    child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? green : muted)),
  );

  Widget _hero(BuildContext context, bool wide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 44 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF173B26), Color(0xFF2E6B43), Color(0xFF4B8E59)]),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(children: [
        Positioned(right: -70, top: -110, child: _orb(240, const Color(0x223B8B4B))),
        Positioned(right: 100, bottom: -150, child: _orb(280, const Color(0x1828B34E))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: .16))),
            child: const Text('✦ AI-POWERED AGRICULTURAL INTELLIGENCE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: wide ? 680 : double.infinity,
            child: Text('Better decisions for healthier soil, stronger crops.', style: TextStyle(color: Colors.white, fontSize: wide ? 44 : 32, height: 1.08, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: wide ? 620 : double.infinity,
            child: Text('AgriN combines farm, soil, weather and environmental intelligence to deliver localized regenerative farming guidance.', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 15, height: 1.6)),
          ),
          const SizedBox(height: 28),
          Wrap(spacing: 12, runSpacing: 12, children: [
            ElevatedButton.icon(
              onPressed: () => context.push('/farm-intelligence'),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Analyze my farm'),
              style: ElevatedButton.styleFrom(foregroundColor: dark, backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/crop-doctor'),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Check a crop'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: .3)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            ),
          ]),
        ]),
      ]),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: .08, end: 0);
  }

  Widget _orb(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color))
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: const Offset(.92, .92), end: const Offset(1.05, 1.05), duration: 4.seconds);
  }

  Widget _metrics(bool wide) {
    final items = [
      ('LIVE', 'Weather • Open-Meteo', Icons.thermostat_rounded),
      ('MODEL', 'Soil • SoilGrids', Icons.layers_outlined),
      ('LIVE', 'Satellite • Sentinel-2', Icons.satellite_alt_rounded),
      ('AI', 'Advisory • Evidence grounded', Icons.auto_awesome_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: wide ? 4 : 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: wide ? 2.3 : 1.65),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5EAE5))),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEAF4EC), borderRadius: BorderRadius.circular(13)), child: Icon(item.$3, color: green, size: 21)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(item.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: dark)),
              const SizedBox(height: 3),
              Text(
                item.$2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: muted, height: 1.25),
              ),
            ])),
          ]),
        ).animate(delay: (100 * index).ms).fadeIn(duration: 500.ms).slideY(begin: .12, end: 0);
      },
    );
  }

  Widget _intelligenceGrid(bool wide) {
    final cards = [
      ('Farm Intelligence', 'Satellite + soil + weather signals', Icons.satellite_alt_rounded, const Color(0xFFEAF3F0)),
      ('AI Agro-Advisory', 'Personalized actions for your crop', Icons.auto_awesome_rounded, const Color(0xFFF2EFE4)),
      ('Crop Doctor', 'Detect possible disease from a photo', Icons.local_florist_rounded, const Color(0xFFF0E9E5)),
      ('Regenerative Farming', 'Build soil health and resilience', Icons.eco_rounded, const Color(0xFFE8F1E9)),
      ('Historical Intelligence', 'Understand weather and satellite change', Icons.history_rounded, const Color(0xFFEAF0E8)),
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: wide ? 3 : 1, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: wide ? 1.25 : 2.8),
      itemBuilder: (context, i) {
        final c = cards[i];
        return Material(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              if (c.$1 == 'Farm Intelligence') {
                context.push('/farm-intelligence');
              } else if (c.$1 == 'Crop Doctor') {
                context.push('/crop-doctor');
              } else if (c.$1 == 'Regenerative Farming') {
                context.push('/regenerative-farming');
              } else if (c.$1 == 'Historical Intelligence') {
                context.push('/historical-intelligence');
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5EAE5))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: c.$4, borderRadius: BorderRadius.circular(15)), child: Icon(c.$3, color: green)),
                const Spacer(),
                Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: dark)),
                const SizedBox(height: 6),
                Text(c.$2, style: const TextStyle(color: muted, fontSize: 12, height: 1.4)),
              ]),
            ),
          ),
        ).animate(delay: (120 * i).ms).fadeIn(duration: 500.ms).slideY(begin: .08, end: 0);
      },
    );
  }

  Widget _bricsBanner(BuildContext context, bool wide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 30 : 24),
      decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), shape: BoxShape.circle), child: const Icon(Icons.public_rounded, color: Colors.white)),
        const SizedBox(width: 16),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BRICS Agricultural Cooperation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 5),
          Text('A shared architecture for sovereign data, models and climate-resilient farming knowledge.', style: TextStyle(color: Color(0xFFAAB7AE), fontSize: 12, height: 1.45)),
        ])),
        if (wide) IconButton(onPressed: () => GoRouter.of(context).push('/brics-network'), icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white54)),
      ]),
    ).animate().fadeIn(duration: 700.ms).slideX(begin: .04, end: 0);
  }
}
