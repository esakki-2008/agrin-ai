import 'dart:convert';
import 'package:http/http.dart' as http;

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
  const SoilService({this.baseUrl = 'http://127.0.0.1:8000'});

  Future<SoilData> fetch({required double latitude, required double longitude}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/soil'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail']?.toString() ?? 'Soil service failed.');
    }
    return SoilData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
