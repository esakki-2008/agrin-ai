import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/interoperability_service.dart';

class BricsNetworkPage extends StatefulWidget {
  const BricsNetworkPage({super.key});

  @override
  State<BricsNetworkPage> createState() => _BricsNetworkPageState();
}

class _BricsNetworkPageState extends State<BricsNetworkPage> {
  static const green = Color(0xFF2E6B43);
  static const dark = Color(0xFF102318);
  static const muted = Color(0xFF66736A);

  final service = InteroperabilityService();
  InteroperabilityProfile? profile;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await service.profile();
      if (!mounted) return;
      setState(() {
        profile = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BRICS-ready Data Network',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 48 : 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hero(),
                  const SizedBox(height: 20),
                  if (loading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ))
                  else if (error != null)
                    _error()
                  else
                    _content(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(
      color: dark,
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.public_rounded, color: Colors.white, size: 36),
        SizedBox(height: 14),
        Text(
          'Interoperability without vendor lock-in',
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 8),
        Text(
          'A country-neutral open data contract for exchanging agricultural observations while keeping source attribution and privacy controls explicit.',
          style: TextStyle(color: Color(0xCCD4DDD7), height: 1.5),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: .05, end: 0);

  Widget _content() {
    final p = profile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          'Open observation profile',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Standard', p.standard),
              _row('Version', p.version),
              _row('Format', p.format),
              _row('Coordinates', 'WGS84 latitude / longitude'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section('Observation groups', p.observationGroups, Icons.dataset_rounded),
        const SizedBox(height: 16),
        _section('Design principles', p.design, Icons.hub_rounded),
        const SizedBox(height: 16),
        _section('Privacy controls', p.privacy, Icons.lock_outline_rounded),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'AgriN does not claim a live government or BRICS data connection here. This layer defines a platform-independent exchange contract that can accept compatible observations from different systems.',
            style: TextStyle(color: dark, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _section(String title, List<String> items, IconData icon) => _card(
    title,
    Column(
      children: items.map((x) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: green),
            const SizedBox(width: 10),
            Expanded(child: Text(x, style: const TextStyle(fontSize: 12, color: dark, height: 1.4))),
          ],
        ),
      )).toList(),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 11, color: muted))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark))),
      ],
    ),
  );

  Widget _card(String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5EAE5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark)),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _error() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFFFFF3F0), borderRadius: BorderRadius.circular(18)),
    child: Text(error!, style: const TextStyle(color: dark)),
  );
}
