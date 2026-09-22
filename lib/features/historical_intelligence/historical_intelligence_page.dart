import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/weather_service.dart';
import '../../services/historical_service.dart';
import '../../theme/agri_n_design.dart';

class HistoricalIntelligencePage extends StatefulWidget {
  const HistoricalIntelligencePage({super.key});
  @override State<HistoricalIntelligencePage> createState() => _HistoricalIntelligencePageState();
}

class _HistoricalIntelligencePageState extends State<HistoricalIntelligencePage> {
  static const green = Color(0xFF2E6B43);
  static const dark = Color(0xFF102318);
  static const muted = Color(0xFF66736A);

  final location = TextEditingController();
  int days = 30;
  bool loading = false;
  String? error;
  HistoricalWeather? history;
  HistoricalSatellite? satellite;
  HistoricalNdvi? ndvi;

  @override
  void dispose() { location.dispose(); super.dispose(); }

  Future<void> analyze() async {
    if (location.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a village, district, or location first.')));
      return;
    }
    setState(() { loading = true; error = null; history = null; satellite = null; ndvi = null; });
    try {
      final live = await WeatherService().fetch(location.text.trim());
      final service = HistoricalService();
      final h = await service.weather(latitude: live.latitude, longitude: live.longitude, days: days);
      HistoricalSatellite? s;
      try {
        s = await service.satelliteScenes(latitude: live.latitude, longitude: live.longitude, days: days);
      } catch (_) {}
      HistoricalNdvi? n;
      try {
        n = await service.satelliteNdvi(latitude: live.latitude, longitude: live.longitude, days: days);
      } catch (_) {}
      if (!mounted) return;
      setState(() { history = h; satellite = s; ndvi = n; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(title: const Text('Historical Intelligence', style: TextStyle(fontWeight: FontWeight.w800))),
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
                  if (history == null) _form() else _results(wide),
                  if (error != null) ...[const SizedBox(height: 18), _error()],
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
    padding: const EdgeInsets.fromLTRB(34, 34, 24, 34),
    color: dark,
    decoration: const BoxDecoration(),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.history_rounded, color: Colors.white, size: 34),
        SizedBox(height: 14),
        Text('See what changed\nover time.', style: TextStyle(color: Colors.white, fontSize: 42, height: .95, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('Read the farm as a sequence of real observations — weather, satellite scenes and NDVI — without turning them into synthetic crop-health claims.', style: TextStyle(color: Color(0xCCDDE9DF), height: 1.5)),
      ],
    ),
  ).animate().fadeIn(duration: 600.ms).slideY(begin: .06, end: 0);

  Widget _form() => _card(
    'Historical window',
    Column(
      children: [
        TextField(controller: location, decoration: _decoration('Village / district / location', Icons.location_on_outlined)).animate().fadeIn(delay: 100.ms, duration: 350.ms),
        const SizedBox(height: 15),
        DropdownButtonFormField<int>(
          value: days,
          decoration: _decoration('Period', Icons.date_range_rounded),
          items: const [30, 60, 90].map((x) => DropdownMenuItem(value: x, child: Text('$x days'))).toList(),
          onChanged: (x) => setState(() => days = x ?? days),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : analyze,
            icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.timeline_rounded),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text(loading ? 'Loading history...' : 'Analyze history')),
            style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          ),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 550.ms).slideX(begin: -.04, end: 0);

  Widget _results(bool wide) {
    final h = history!;
    final s = satellite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OBSERVATION TIMELINE', style: TextStyle(fontSize:9, letterSpacing:1.8, fontWeight:FontWeight.w800, color:green)),
        const SizedBox(height:8),
        Text('Historical farm intelligence', style: TextStyle(fontSize: wide ? 38 : 29, fontWeight: FontWeight.w800, color: dark)),
        const SizedBox(height: 6),
        Text(h.startDate + ' → ' + h.endDate, style: const TextStyle(color: muted)),
        const SizedBox(height: 18),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: wide ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _metric(h.summary.averageTemperature == null ? 'Unavailable' : h.summary.averageTemperature!.toStringAsFixed(1) + '°C', 'Average temperature'),
            _metric(h.summary.totalPrecipitation == null ? 'Unavailable' : h.summary.totalPrecipitation!.toStringAsFixed(1) + ' mm', 'Total precipitation'),
            _metric(h.summary.averageEt0 == null ? 'Unavailable' : h.summary.averageEt0!.toStringAsFixed(1) + ' mm', 'Average daily ET₀'),
            _metric(h.summary.temperatureTrend, 'Temperature trend'),
          ],
        ),
        const SizedBox(height: 22),
        _sectionTitle('Recent daily observations'),
        const SizedBox(height: 10),
        _dailyList(h.daily),
        const SizedBox(height: 22),
        _sectionTitle('Sentinel-2 observation history'),
        const SizedBox(height: 10),
        if (s == null || s.scenes.isEmpty)
          _empty('No Sentinel-2 scenes were returned for this period.')
        else ...[
          Text(s.count.toString() + ' scenes found • ' + s.source, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 10),
          ...s.scenes.take(8).map(_scene),
        ],
        const SizedBox(height: 22),
        _ndviSection(),
        const SizedBox(height: 18),
        _changeAnalysis(),
        const SizedBox(height: 18),
        _limitations(),
      ],
    ).animate().fadeIn(duration: 650.ms).slideY(begin: .05, end: 0);
  }

  Widget _dailyList(List<HistoricalDay> rows) {
    final recent = rows.reversed.take(7).toList();
    return Column(
      children: recent.map((x) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AgriNDesign.line)),
        child: Row(
          children: [
            SizedBox(width: 92, child: Text(x.date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dark))),
            Expanded(child: Text(x.temperature == null ? 'Temperature unavailable' : x.temperature!.toStringAsFixed(1) + '°C', style: const TextStyle(fontSize: 12, color: muted))),
            Text(x.precipitation == null ? 'Rain unavailable' : x.precipitation!.toStringAsFixed(1) + ' mm', style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _scene(HistoricalScene x) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AgriNDesign.line)),
    child: Row(
      children: [
        const Icon(Icons.satellite_alt_rounded, color: green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.datetime == null ? 'Observation date unavailable' : x.datetime!.substring(0, 10), style: const TextStyle(fontWeight: FontWeight.w700, color: dark)),
            const SizedBox(height: 4),
            Text(x.id ?? 'Scene ID unavailable', style: const TextStyle(fontSize: 10, color: muted)),
          ]),
        ),
        Text(x.cloudCover == null ? 'Cloud unavailable' : x.cloudCover!.toStringAsFixed(1) + '%', style: const TextStyle(fontSize: 11, color: muted)),
      ],
    ),
  ).animate().fadeIn(duration: 350.ms).slideX(begin: .02, end: 0);

  Widget _metric(String value, String label) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AgriNDesign.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
    ]),
  ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(.97, .97), end: const Offset(1, 1));

  Widget _ndviSection() {
    final n = ndvi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Historical Sentinel-2 NDVI'),
        const SizedBox(height: 6),
        const Text('NDVI calculated from real Red and NIR observations. It is a point sample, not a whole-farm health score.', style: TextStyle(fontSize: 11, color: muted, height: 1.4)),
        const SizedBox(height: 10),
        if (n == null || !n.available || n.observations.isEmpty)
          _empty(n?.message ?? 'Historical NDVI is unavailable.')
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5EAE5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 220, child: CustomPaint(painter: _NdviChartPainter(n.observations), child: const SizedBox.expand())),
              const SizedBox(height: 8),
              Text(n.count.toString() + ' usable observations • ' + n.source, style: const TextStyle(fontSize: 10, color: muted)),
            ]),
          ),
      ],
    );
  }
  Widget _changeAnalysis() {
    final n = ndvi;
    final h = history!;
    if (n == null || n.observations.length < 2) {
      return _empty('Historical change analysis is unavailable because fewer than two usable NDVI observations were returned.');
    }

    final first = n.observations.first;
    final last = n.observations.last;
    final change = last.ndvi - first.ndvi;
    final percent = first.ndvi.abs() > 0.000001 ? (change / first.ndvi.abs()) * 100 : null;

    String direction;
    if (change > 0.000001) {
      direction = 'Observed NDVI increased';
    } else if (change < -0.000001) {
      direction = 'Observed NDVI decreased';
    } else {
      direction = 'Observed NDVI was unchanged';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Observed historical change'),
          const SizedBox(height: 8),
          Text(direction, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _changeMetric(first.ndvi.toStringAsFixed(3), first.date == null ? 'First NDVI' : 'First • ${first.date!.substring(0, 10)}')),
              const SizedBox(width: 10),
              Expanded(child: _changeMetric(last.ndvi.toStringAsFixed(3), last.date == null ? 'Latest NDVI' : 'Latest • ${last.date!.substring(0, 10)}')),
              const SizedBox(width: 10),
              Expanded(child: _changeMetric(change.toStringAsFixed(3), 'Absolute change')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            percent == null
                ? 'Relative change is unavailable because the first NDVI observation is zero.'
                : 'Relative change from the first to the latest usable observation: ${percent.toStringAsFixed(1)}%.',
            style: const TextStyle(fontSize: 11, color: muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            'Weather context for this period: ${h.summary.totalPrecipitation?.toStringAsFixed(1) ?? 'Unavailable'} mm total precipitation and ${h.summary.averageTemperature?.toStringAsFixed(1) ?? 'Unavailable'}°C average temperature. These are contextual observations, not a causal diagnosis of crop condition.',
            style: const TextStyle(fontSize: 11, color: muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _changeMetric(String value, String label) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AgriNDesign.line)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark)),
        const SizedBox(height: 4),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: muted)),
      ],
    ),
  );

  Widget _limitations() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: const BoxDecoration(color: dark),
    child: const Text(
      'Historical weather is sourced from Open-Meteo archive data. Sentinel-2 entries are scene metadata; scene count and cloud cover are not crop-health scores. Historical NDVI change is calculated only from usable Sentinel-2 observations returned for this point and period. Weather values provide context; they do not establish causation.',
      style: TextStyle(color: Color(0xFFD4DDD7), fontSize: 11, height: 1.5),
    ),
  );

  Widget _empty(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AgriNDesign.line)),
    child: Text(text, style: const TextStyle(color: muted)),
  );

  Widget _error() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: const BoxDecoration(color: Color(0xFFFFF1EC), border: Border(left: BorderSide(color: Colors.deepOrange, width: 3))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.deepOrange),
      const SizedBox(width: 10),
      Expanded(child: Text(error!, style: const TextStyle(color: dark))),
    ]),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: green),
    filled: true,
    fillColor: const Color(0xFFF7F9F5),
    border: const OutlineInputBorder(borderSide: BorderSide(color: AgriNDesign.line)),
  );

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: dark));

  Widget _card(String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AgriNDesign.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 18),
      child,
    ]),
  );
}


class _NdviChartPainter extends CustomPainter {
  final List<HistoricalNdviObservation> observations;
  _NdviChartPainter(this.observations);

  @override
  void paint(Canvas canvas, Size size) {
    if (observations.isEmpty) return;
    final chart = Rect.fromLTWH(42, 12, size.width - 58, size.height - 42);
    final gridPaint = Paint()..color = const Color(0xFFE5EAE5)..strokeWidth = 1;
    final linePaint = Paint()..color = const Color(0xFF2E6B43)..strokeWidth = 3..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = const Color(0xFF2E6B43)..style = PaintingStyle.fill;
    const minY = -1.0;
    const maxY = 1.0;

    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = maxY - (maxY - minY) * i / 4;
      _text(canvas, value.toStringAsFixed(1), Offset(2, y - 7), 10);
    }

    final path = Path();
    for (var i = 0; i < observations.length; i++) {
      final x = observations.length == 1 ? chart.center.dx : chart.left + chart.width * i / (observations.length - 1);
      final normalized = (observations[i].ndvi - minY) / (maxY - minY);
      final y = chart.bottom - normalized * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
    canvas.drawPath(path, linePaint);

    final first = observations.first.date ?? '';
    final last = observations.last.date ?? '';
    if (first.isNotEmpty) _text(canvas, first.length >= 10 ? first.substring(0, 10) : first, Offset(chart.left, chart.bottom + 10), 9);
    if (last.isNotEmpty) {
      final label = last.length >= 10 ? last.substring(0, 10) : last;
      _text(canvas, label, Offset(chart.right - 65, chart.bottom + 10), 9);
    }
  }

  void _text(Canvas canvas, String text, Offset offset, double size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: const Color(0xFF66736A), fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _NdviChartPainter oldDelegate) => oldDelegate.observations != observations;
}
