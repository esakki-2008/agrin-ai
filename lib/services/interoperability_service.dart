import 'dart:convert';
import 'package:http/http.dart' as http;

class InteroperabilityProfile {
  final String standard;
  final String version;
  final String format;
  final List<String> design;
  final List<String> observationGroups;
  final List<String> privacy;

  const InteroperabilityProfile({
    required this.standard,
    required this.version,
    required this.format,
    required this.design,
    required this.observationGroups,
    required this.privacy,
  });
}

class InteroperabilityService {
  static const baseUrl = 'http://127.0.0.1:8000';

  Future<InteroperabilityProfile> profile() async {
    final response = await http.get(
      Uri.parse(baseUrl + '/interoperability/profile'),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Interoperability profile unavailable (' + response.statusCode.toString() + ').');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return InteroperabilityProfile(
      standard: body['standard'].toString(),
      version: body['version'].toString(),
      format: body['format'].toString(),
      design: (body['design'] as List).map((x) => x.toString()).toList(),
      observationGroups: (body['observation_groups'] as List).map((x) => x.toString()).toList(),
      privacy: (body['privacy'] as List).map((x) => x.toString()).toList(),
    );
  }

  Future<Map<String, dynamic>> export({
    required String countryCode,
    required String locationName,
    required double latitude,
    required double longitude,
    required String observedAt,
    Map<String, dynamic>? weather,
    Map<String, dynamic>? soil,
    Map<String, dynamic>? satellite,
    String? crop,
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl + '/interoperability/export'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'country_code': countryCode,
        'location_name': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'observed_at': observedAt,
        'weather': weather,
        'soil': soil,
        'satellite': satellite,
        'crop': crop,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Observation export failed (' + response.statusCode.toString() + ').');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validate({
    required String countryCode,
    required String locationName,
    required double latitude,
    required double longitude,
    required String observedAt,
    String? crop,
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl + '/interoperability/validate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'country_code': countryCode,
        'location_name': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'observed_at': observedAt,
        'crop': crop,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Observation validation failed (' + response.statusCode.toString() + ').');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
