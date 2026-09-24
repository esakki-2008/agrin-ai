import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/agri_n_design.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = wide ? 56.0 : 20.0;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 22),
              sliver: SliverToBoxAdapter(child: _nav(context, wide)),
            ),
            SliverToBoxAdapter(child: _hero(context, wide)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverToBoxAdapter(child: _intro(wide)),
            ),
            SliverToBoxAdapter(child: _intelligenceStrip(wide)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverToBoxAdapter(child: _capabilities(context, wide)),
            ),
            SliverToBoxAdapter(child: _agentSection(context, wide)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverToBoxAdapter(child: _networkSection(context, wide)),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 42),
              sliver: SliverToBoxAdapter(child: _footer()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nav(BuildContext context, bool wide) {
    return Row(
      children: [
        Text('AGRI N', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2.8)),
        const Spacer(),
        if (wide) ...[
          _link(context, 'FARM', '/farm-intelligence'),
          _link(context, 'DOCTOR', '/crop-doctor'),
          _link(context, 'HISTORY', '/historical-intelligence'),
          _link(context, 'NETWORK', '/brics-network'),
          _link(context, 'TWIN', '/farm-digital-twin'),
        ],
        const SizedBox(width: 16),
        Text('INDIA', style: Theme.of(context).textTheme.labelSmall),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -.12, end: 0);
  }

  Widget _link(BuildContext context, String label, String route) => Padding(
    padding: const EdgeInsets.only(left: 22),
    child: InkWell(
      onTap: () => context.push(route),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AgriNDesign.ink)),
    ),
  );

  Widget _hero(BuildContext context, bool wide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 20, vertical: wide ? 76 : 58),
      decoration: const BoxDecoration(color: AgriNDesign.paper),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: wide ? 90 : -45,
            top: wide ? -20 : 12,
            child: MotionOrb(size: wide ? 300 : 190, label: 'LIVING\nLAND'),
          ),
          Positioned(
            right: wide ? 270 : -10,
            bottom: -70,
            child: MotionOrb(size: wide ? 170 : 110, label: 'FIELD'),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 780 : 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AGRICULTURAL\nINTELLIGENCE', style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: wide ? 92 : 58,
                  height: .82,
                  fontWeight: FontWeight.w500,
                  color: AgriNDesign.ink,
                )).animate().fadeIn(duration: 800.ms).slideX(begin: -.04, end: 0),
                const SizedBox(height: 28),
                Text(
                  'Evidence from weather, soil, satellite and history — brought together for better farm decisions.',
                  style: TextStyle(fontSize: wide ? 16 : 14, height: 1.6, color: AgriNDesign.muted),
                ).animate(delay: 180.ms).fadeIn(duration: 650.ms),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _action('ANALYZE FARM', () => context.push('/farm-intelligence')),
                    _action('CROP DOCTOR', () => context.push('/crop-doctor'), outline: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms);
  }

  Widget _action(String label, VoidCallback onTap, {bool outline = false}) {
    return outline
        ? OutlinedButton(onPressed: onTap, child: Text(label))
        : ElevatedButton(onPressed: onTap, child: Text(label));
  }

  Widget _intro(bool wide) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const EditorialRule(margin: EdgeInsets.only(top: 16)),
      const SizedBox(height: 26),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text('THE FARM / 01', style: TextStyle(fontSize: wide ? 12 : 10, letterSpacing: 2.2, fontWeight: FontWeight.w700, color: AgriNDesign.muted))),
          Expanded(child: Text('AgriN treats every observation as evidence — with its source, date and limitations kept visible.', style: TextStyle(fontSize: wide ? 15 : 13, height: 1.55, color: AgriNDesign.ink))),
        ],
      ),
      const SizedBox(height: 34),
    ],
  );

  Widget _intelligenceStrip(bool wide) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 20, vertical: 22),
    color: AgriNDesign.ink,
    child: Row(
      children: [
        Expanded(child: _stripItem('01', 'WEATHER', 'Open-Meteo')),
        Expanded(child: _stripItem('02', 'SOIL', 'ISRIC SoilGrids')),
        Expanded(child: _stripItem('03', 'SATELLITE', 'Sentinel-2')),
        if (wide) Expanded(child: _stripItem('04', 'AI', 'Evidence grounded')),
      ],
    ),
  ).animate().fadeIn(duration: 700.ms).slideY(begin: .08, end: 0);

  Widget _stripItem(String n, String title, String source) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      children: [
        Text(n, style: const TextStyle(color: Color(0xFF7F877F), fontSize: 10, letterSpacing: 1)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
          const SizedBox(height: 3),
          Text(source, style: const TextStyle(color: Color(0xFF9DA59E), fontSize: 10)),
        ])),
      ],
    ),
  );

  Widget _capabilities(BuildContext context, bool wide) {
    final items = [
      ('02', 'FARM INTELLIGENCE', 'Combine location, soil, weather and satellite observations.', '/farm-intelligence'),
      ('03', 'AI AGRO-ADVISORY', 'Turn measured signals into explainable actions.', '/ai-advisory'),
      ('04', 'CROP DOCTOR', 'Inspect a crop image with evidence-aware visual analysis.', '/crop-doctor'),
      ('05', 'REGENERATIVE FARMING', 'Explore soil-cover, rotation and resilience practices.', '/regenerative-farming'),
      ('06', 'HISTORICAL INTELLIGENCE', 'Compare observed weather and Sentinel-2 change over time.', '/historical-intelligence'),
      ('07', 'FARM DIGITAL TWIN', 'Build a refreshable farm state from weather, soil and satellite observations.', '/farm-digital-twin'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialRule(),
        const SizedBox(height: 22),
        Text('INTELLIGENCE / 02', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 24),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return InkWell(
            onTap: () => context.push(item.$4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: wide ? 90 : 48, child: Text(item.$1, style: Theme.of(context).textTheme.labelSmall)),
                  Expanded(child: Text(item.$2, style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: wide ? 38 : 27, height: 1.0, color: AgriNDesign.ink))),
                  if (wide) SizedBox(width: 280, child: Text(item.$3, style: Theme.of(context).textTheme.bodyMedium)),
                  const Icon(Icons.arrow_outward_rounded, size: 18),
                ],
              ),
            ),
          ).animate(delay: (80 * i).ms).fadeIn(duration: 500.ms).slideX(begin: .025, end: 0);
        }),
      ],
    );
  }

  Widget _agentSection(BuildContext context, bool wide) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 30),
      padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 20, vertical: wide ? 72 : 52),
      color: AgriNDesign.paper2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('INTELLIGENCE AGENT', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 16),
              Text('FROM SIGNALS\nTO DECISIONS.', style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: wide ? 66 : 45, height: .9, color: AgriNDesign.ink)),
              const SizedBox(height: 18),
              Text('A farm decision loop that gathers evidence, reasons over it, explains limitations and identifies what should be checked next.', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 26),
              ElevatedButton(onPressed: () => context.push('/intelligence-agent'), child: const Text('RUN INTELLIGENCE AGENT')),
            ]),
          ),
          if (wide) ...[
            const SizedBox(width: 40),
            const Expanded(child: Center(child: MotionOrb(size: 270, label: 'WEATHER\nSOIL\nSATELLITE\nHISTORY'))),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: .05, end: 0);
  }

  Widget _networkSection(BuildContext context, bool wide) => Padding(
    padding: const EdgeInsets.only(top: 34),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const EditorialRule(),
      const SizedBox(height: 22),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NETWORK / 08', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 15),
          Text('OPEN AGRICULTURAL\nOBSERVATIONS.', style: TextStyle(fontFamily: 'Cormorant Garamond', fontSize: wide ? 54 : 38, height: .9, color: AgriNDesign.ink)),
        ])),
        if (wide) Expanded(child: Text('A platform-independent observation contract for sharing agricultural data with source attribution and explicit privacy controls.', style: Theme.of(context).textTheme.bodyLarge)),
      ]),
      const SizedBox(height: 22),
      OutlinedButton(onPressed: () => context.push('/brics-network'), child: const Text('OPEN NETWORK')),
    ]),
  );

  Widget _footer() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      EditorialRule(),
      SizedBox(height: 18),
      Row(children: [
        Text('AGRI N', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        Spacer(),
        Text('EVIDENCE • RESILIENCE • OPEN DATA', style: TextStyle(fontSize: 9, letterSpacing: 1.1, color: AgriNDesign.muted)),
      ]),
    ],
  );
}
