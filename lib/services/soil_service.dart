import 'api_client.dart';
import '../config/api_config.dart';

class SoilData {
  final double ph;
  final double organicCarbon;
  final double nitrogen;
  final double clay;
  final String source;
  final int resolution;
  final String depth;

  const SoilData({
    required this.ph,
    required this.organicCarbon,
    required this.nitrogen,
    required this.clay,
    required this.source,
    required this.resolution,
    required this.depth,
  });

  factory SoilData.fromJson(Map<String, dynamic> json) => SoilData(
    ph: (json['ph'] as num).toDouble(),
    organicCarbon: (json['organic_carbon_g_kg'] as num).toDouble(),
    nitrogen: (json['nitrogen_g_kg'] as num).toDouble(),
    clay: (json['clay_percent'] as num).toDouble(),
    source: json['source'].toString(),
    resolution: (json['resolution_m'] as num).toInt(),
    depth: json['depth'].toString(),
  );
}

class SoilService {
  final String baseUrl;
  SoilService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<SoilData> fetch({required double latitude, required double longitude}) async {
    final json = await const ApiClient().postJson(
      '/soil',
      body: {'latitude': latitude, 'longitude': longitude},
      timeout: const Duration(seconds: 45),
    );
    return SoilData.fromJson(json);
  }
}
