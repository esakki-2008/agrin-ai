import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ClimateIntelligenceData {
  final bool available;
  final Map<String, dynamic>? summary;
  final List<dynamic> daily;
  final List<dynamic> signals;
  final List<dynamic> limitations;
  final String source;

  const ClimateIntelligenceData({
    required this.available,
    required this.source,
    this.summary,
    this.daily = const [],
    this.signals = const [],
    this.limitations = const [],
  });

  factory ClimateIntelligenceData.fromJson(Map<String, dynamic> json) {
    return ClimateIntelligenceData(
      available: json['available'] == true,
      source: json['source']?.toString() ?? 'Climate data',
      summary: json['summary'] as Map<String, dynamic>?,
      daily: (json['daily'] as List<dynamic>?) ?? const [],
      signals: (json['signals'] as List<dynamic>?) ?? const [],
      limitations: (json['limitations'] as List<dynamic>?) ?? const [],
    );
  }

  double? number(String key) {
    final value = summary?[key];
    return value is num ? value.toDouble() : null;
  }
}

class ClimateService {
  final String baseUrl;
  ClimateService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<ClimateIntelligenceData> fetch({
    required double latitude,
    required double longitude,
    int forecastDays = 7,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/climate/intelligence'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'forecast_days': forecastDays,
      }),
    ).timeout(const Duration(seconds: 60));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['detail']?.toString() ?? 'Climate intelligence failed.');
    }
    return ClimateIntelligenceData.fromJson(json);
  }
}
