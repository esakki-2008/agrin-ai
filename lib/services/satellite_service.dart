import 'dart:convert';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;

class SatelliteData {
  final bool available;
  final String source;
  final String? sceneId;
  final String? observationDate;
  final double? cloudCover;
  final double? ndvi;
  const SatelliteData({required this.available, required this.source, this.sceneId, this.observationDate, this.cloudCover, this.ndvi});
  factory SatelliteData.fromJson(Map<String, dynamic> json) => SatelliteData(
    available: json['available'] == true,
    source: json['source']?.toString() ?? 'Satellite data',
    sceneId: json['scene_id']?.toString(),
    observationDate: json['observation_date']?.toString(),
    cloudCover: (json['cloud_cover_percent'] as num?)?.toDouble(),
    ndvi: (json['ndvi'] as num?)?.toDouble(),
  );
}

class SatelliteService {
  final String baseUrl;
  const SatelliteService({this.baseUrl = 'http://127.0.0.1:8000'});
  Future<SatelliteData> fetch({required double latitude, required double longitude, int days = 90, double maxCloudCover = 50}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/satellite/ndvi'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'latitude': latitude, 'longitude': longitude, 'days': days, 'max_cloud_cover': maxCloudCover}),
    ).timeout(const Duration(seconds: 90));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) throw Exception(json['detail']?.toString() ?? 'Satellite service failed.');
    return SatelliteData.fromJson(json);
  }
}
