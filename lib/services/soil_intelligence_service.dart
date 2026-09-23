import 'api_client.dart';
import '../config/api_config.dart';

class SoilProfileData {
  final bool available;
  final String source;
  final int resolution;
  final List<dynamic> profile;
  final List<dynamic> errors;
  final List<dynamic> limitations;

  const SoilProfileData({
    required this.available,
    required this.source,
    required this.resolution,
    required this.profile,
    required this.errors,
    required this.limitations,
  });

  factory SoilProfileData.fromJson(Map<String,dynamic> json) => SoilProfileData(
    available: json['available'] == true,
    source: json['source']?.toString() ?? 'Soil data',
    resolution: (json['resolution_m'] as num?)?.toInt() ?? 250,
    profile: (json['profile'] as List<dynamic>?) ?? const [],
    errors: (json['errors'] as List<dynamic>?) ?? const [],
    limitations: (json['limitations'] as List<dynamic>?) ?? const [],
  );

  double? value(int index, String key) {
    if(index < 0 || index >= profile.length) return null;
    final row=profile[index];
    if(row is! Map) return null;
    final v=row[key];
    return v is num ? v.toDouble() : null;
  }
}

class SoilIntelligenceService {
  final String baseUrl;
  SoilIntelligenceService({String? baseUrl}) : baseUrl=baseUrl ?? ApiConfig.baseUrl;

  Future<SoilProfileData> fetch({required double latitude, required double longitude}) async {
    final json = await const ApiClient().postJson(
      '/soil-intelligence/profile',
      body: {'latitude': latitude, 'longitude': longitude},
      timeout: const Duration(seconds: 120),
    );
    return SoilProfileData.fromJson(json);
  }
}
