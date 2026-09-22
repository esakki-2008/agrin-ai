import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import '../../services/interoperability_service.dart';
import '../../services/weather_service.dart';
import '../../services/soil_service.dart';
import '../../services/satellite_service.dart';
import '../../theme/agri_n_design.dart';
import '../../services/agri_network_service.dart';

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
  bool exporting = false;
  final locationController = TextEditingController(text: 'Nashik, Maharashtra');
  String crop = 'Rice';
  Map<String, dynamic>? exportedObservation;
  String? exportError;
  final importController = TextEditingController();
  bool validating = false;
  final networkService = AgriNetworkService();
  Map<String, dynamic>? networkManifest;
  String? networkError;
  Map<String, dynamic>? validationResult;
  String? validationError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await service.profile();
      try {
        networkManifest = await networkService.manifest();
      } catch (e) {
        networkError = e.toString().replaceFirst('Exception: ', '');
      }
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
  void dispose() {
    locationController.dispose();
    importController.dispose();
    super.dispose();
  }

  Future<void> _validateImportedObservation() async {
    final raw = importController.text.trim();
    if (raw.isEmpty) {
      setState(() { validationError = 'Paste a standardized JSON observation first.'; validationResult = null; });
      return;
    }
    setState(() { validating = true; validationError = null; validationResult = null; });
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) throw Exception('The JSON root must be an object.');
      final observation = decoded['observation'] is Map
          ? Map<String, dynamic>.from(decoded['observation'] as Map)
          : decoded;
      final result = await service.validateObservation(observation);
      if (!mounted) return;
      setState(() { validationResult = result; validating = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        validationError = e.toString().replaceFirst('Exception: ', '');
        validating = false;
      });
    }
  }

  Future<void> _exportLiveObservation() async {
    setState(() { exporting = true; exportError = null; exportedObservation = null; });
    try {
      final weather = await WeatherService().fetch(locationController.text.trim());
      final soil = await SoilService().fetch(latitude: weather.latitude, longitude: weather.longitude);
      SatelliteData? satellite;
      try {
        satellite = await SatelliteService().fetch(latitude: weather.latitude, longitude: weather.longitude);
      } catch (_) {
        satellite = null;
      }

      final result = await service.export(
        countryCode: 'IN',
        locationName: weather.location,
        latitude: weather.latitude,
        longitude: weather.longitude,
        observedAt: DateTime.now().toUtc().toIso8601String(),
        weather: {
          'source': 'Open-Meteo',
          'temperature_c': weather.temperature,
          'humidity_percent': weather.humidity,
          'wind_speed_kmh': weather.windSpeed,
          'precipitation_mm': weather.precipitation,
          'rain_probability_percent': weather.rainProbability,
          'weather_code': weather.weatherCode,
          'observed_at': weather.time,
        },
        soil: {
          'source': soil.source,
          'pH': soil.ph,
          'organic_carbon_g_kg': soil.organicCarbon,
          'nitrogen_g_kg': soil.nitrogen,
          'clay_percent': soil.clay,
          'resolution_m': soil.resolution,
          'depth': soil.depth,
        },
        satellite: satellite == null ? null : {
          'source': satellite.source,
          'scene_id': satellite.sceneId,
          'observation_date': satellite.observationDate,
          'cloud_cover_percent': satellite.cloudCover,
          'ndvi': satellite.ndvi,
        },
        crop: crop,
      );
      if (!mounted) return;
      setState(() { exportedObservation = result; exporting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { exportError = e.toString().replaceFirst('Exception: ', ''); exporting = false; });
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
    color: AgriNDesign.ink,
    padding: const EdgeInsets.fromLTRB(36, 36, 24, 36),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('OPEN DATA NETWORK / 07', style: TextStyle(color: Color(0xFF9EB6A5), fontSize: 9, letterSpacing: 1.9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Text('Agriculture that\ncan speak across systems.', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white, fontSize: 50, height: .9)),
        const SizedBox(height: 18),
        const Text('A country-neutral observation contract for exchanging agricultural evidence while preserving source attribution, coordinates and privacy controls.', style: TextStyle(color: Color(0xCCDDE9DF), fontSize: 13, height: 1.6)),
      ])),
      const SizedBox(width: 20),
      const SizedBox(width: 220, height: 220, child: _NetworkOrb()),
    ]),
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
        _networkProtocolCard(),
        const SizedBox(height: 16),
        _exportCard(),
        const SizedBox(height: 16),
        _importCard(),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EC),
            borderRadius: BorderRadius.zero,
          ),
          child: const Text(
            'AgriN does not claim a live government or BRICS data connection here. This layer defines a platform-independent exchange contract that can accept compatible observations from different systems.',
            style: TextStyle(color: dark, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 650.ms).slideY(begin: .025, end: 0);
  }

  Widget _networkProtocolCard() => _card(
    'AgriN Open Agricultural Network',
    networkManifest == null
        ? Text(networkError ?? 'Network manifest unavailable.', style: const TextStyle(color: muted, fontSize: 12))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Protocol', networkManifest!['protocol_version']?.toString() ?? '—'),
              _row('Status', networkManifest!['status']?.toString() ?? '—'),
              _row('Exchange', 'JSON / WGS84 / HTTP API'),
              const SizedBox(height: 12),
              const Text('Federated-ready means AgriN can package observations for another compatible system without requiring a shared database or vendor-specific storage.', style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
            ],
          ),
  );

  Widget _exportCard() => _card(
    'Create a live standardized observation',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Build an interoperable JSON observation from the same live weather, soil and satellite sources used by AgriN.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            prefixIcon: Icon(Icons.location_on_outlined, color: green),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: crop,
          decoration: const InputDecoration(
            labelText: 'Crop',
            prefixIcon: Icon(Icons.grass_outlined, color: green),
            border: OutlineInputBorder(),
          ),
          items: const ['Rice','Wheat','Cotton','Sugarcane','Tomato','Other']
              .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: exporting ? null : (x) => setState(() => crop = x ?? crop),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: exporting ? null : _exportLiveObservation,
            icon: exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(exporting ? 'Building live observation...' : 'Build & export observation'),
            ),
          ),
        ),
        if (exportError != null) ...[
          const SizedBox(height: 12),
          Text(exportError!, style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
        ],
        if (exportedObservation != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F4),
              borderRadius: BorderRadius.zero,
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(exportedObservation),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.45),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _importCard() => _card(
    'Validate an external observation',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paste a compatible AgriN observation JSON to validate its country code, WGS84 coordinates, timestamp and source-attribution support.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: importController,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'Paste observation JSON here...',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: validating ? null : _validateImportedObservation,
            icon: validating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(validating ? 'Validating...' : 'Validate observation'),
            ),
          ),
        ),
        if (validationError != null) ...[
          const SizedBox(height: 12),
          Text(validationError!, style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
        ],
        if (validationResult != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: validationResult!['valid'] == true ? const Color(0xFFEAF3EC) : const Color(0xFFFFF3F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  validationResult!['valid'] == true ? Icons.check_circle : Icons.error,
                  color: validationResult!['valid'] == true ? green : Colors.deepOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    validationResult!['valid'] == true
                        ? 'Observation accepted by the AgriN validation contract.'
                        : 'Observation failed validation.',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: dark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(validationResult),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.45),
          ),
        ],
      ],
    ),
  );

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
      borderRadius: BorderRadius.zero,
      border: Border.all(color: const Color(0xFFE5EAE5)),
      boxShadow: const [
        BoxShadow(
          blurRadius: 18,
          offset: Offset(0, 8),
          color: Color(0x0D102318),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark)),
        const SizedBox(height: 16),
        child,
      ],
    ),
  ).animate().fadeIn(duration: 500.ms).slideY(begin: .035, end: 0);

  Widget _error() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFFFFF3F0), borderRadius: BorderRadius.zero),
    child: Text(error!, style: const TextStyle(color: dark)),
  );
}

class _NetworkOrb extends StatelessWidget {
  const _NetworkOrb();
  @override Widget build(BuildContext context)=>Stack(alignment:Alignment.center,children:[
    Container(width:215,height:215,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x335E7865)))),
    Container(width:155,height:155,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0x6685A18B)))),
    Container(width:75,height:75,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0x332E6B43),border:Border.all(color:const Color(0x889AB6A2))),child:const Icon(Icons.hub_outlined,color:Color(0xFFD8E3DB),size:30)),
    const Positioned(top:2,right:25,child:_NetworkTag('WGS84')),
    const Positioned(left:0,bottom:48,child:_NetworkTag('JSON')),
    const Positioned(right:0,bottom:20,child:_NetworkTag('SOURCE')),
  ]);
}
class _NetworkTag extends StatelessWidget {
  const _NetworkTag(this.text); final String text;
  @override Widget build(BuildContext context)=>Container(color:const Color(0xDD151914),padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),child:Text(text,style:const TextStyle(color:Color(0xFFB5C2B9),fontSize:7,letterSpacing:1.1,fontWeight:FontWeight.w700)));
}
