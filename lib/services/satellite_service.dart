import 'api_client.dart';

class SatelliteData {
  final bool available;
  final String source;
  final String? sceneId;
  final String? observationDate;
  final double? cloudCover;
  final double? ndvi;

  const SatelliteData({
    required this.available,
    required this.source,
    this.sceneId,
    this.observationDate,
    this.cloudCover,
    this.ndvi,
  });

  factory SatelliteData.fromJson(Map<String, dynamic> json) => SatelliteData(
    available: json['available'] == true,
    source: json['source']?.toString() ?? 'Satellite data',
    sceneId: json['scene_id']?.toString(),
    observationDate: json['observation_date']?.toString(),
    cloudCover: (json['cloud_cover_percent'] as num?)?.toDouble(),
    ndvi: (json['ndvi'] as num?)?.toDouble(),
  );
}

class AdvancedSatelliteData {
  final bool available;
  final Map<String, dynamic>? latest;
  final Map<String, dynamic>? previous;
  final Map<String, dynamic>? change;
  final Map<String, dynamic>? selection;
  final List<dynamic> errors;

  const AdvancedSatelliteData({
    required this.available,
    this.latest,
    this.previous,
    this.change,
    this.selection,
    this.errors = const [],
  });

  factory AdvancedSatelliteData.fromJson(Map<String, dynamic> json) {
    return AdvancedSatelliteData(
      available: json['available'] == true,
      latest: json['latest'] as Map<String, dynamic>?,
      previous: json['previous'] as Map<String, dynamic>?,
      change: json['change'] as Map<String, dynamic>?,
      selection: json['selection'] as Map<String, dynamic>?,
      errors: (json['errors'] as List<dynamic>?) ?? const [],
    );
  }

  double? index(String scene, String name) {
    final source = scene == 'latest' ? latest : previous;
    final indices = source?['indices'];
    if (indices is! Map) return null;
    final value = indices[name];
    return value is num ? value.toDouble() : null;
  }

  double? delta(String name) {
    final values = change?['absolute_index_change'];
    if (values is! Map) return null;
    final value = values[name];
    return value is num ? value.toDouble() : null;
  }

  String? sceneDate(String scene) {
    final source = scene == 'latest' ? latest : previous;
    return source?['observation_date']?.toString();
  }

  double? sceneCloud(String scene) {
    final source = scene == 'latest' ? latest : previous;
    final value = source?['cloud_cover_percent'];
    return value is num ? value.toDouble() : null;
  }
}

class SatelliteService {
  final String baseUrl;

  SatelliteService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<SatelliteData> fetch({
    required double latitude,
    required double longitude,
    int days = 90,
    double maxCloudCover = 50,
  }) async {
    final json = await const ApiClient().postJson(
      '/satellite/ndvi',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'days': days,
        'max_cloud_cover': maxCloudCover,
      },
      timeout: const Duration(seconds: 90),
    );
    return SatelliteData.fromJson(json);
  }

  Future<AdvancedSatelliteData> fetchIntelligence({
    required double latitude,
    required double longitude,
    int days = 180,
    double maxCloudCover = 30,
  }) async {
    final json = await const ApiClient().postJson(
      '/satellite/intelligence',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'days': days,
        'max_cloud_cover': maxCloudCover,
      },
      timeout: const Duration(seconds: 120),
    );
    return AdvancedSatelliteData.fromJson(json);
  }
}
