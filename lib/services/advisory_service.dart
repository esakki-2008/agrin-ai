import 'dart:convert';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import 'weather_service.dart';
import 'soil_service.dart';
import 'satellite_service.dart';

class AdvisoryAction {
  final String title;
  final String reason;
  final String priority;
  final String confidence;
  const AdvisoryAction({required this.title, required this.reason, required this.priority, required this.confidence});
  factory AdvisoryAction.fromJson(Map<String, dynamic> json) => AdvisoryAction(
    title: json['title']?.toString() ?? 'Action',
    reason: json['reason']?.toString() ?? '',
    priority: json['priority']?.toString() ?? 'medium',
    confidence: json['confidence']?.toString() ?? 'medium',
  );
}

class AdvisoryData {
  final String summary;
  final List<String> observations;
  final List<AdvisoryAction> actions;
  final List<String> watchItems;
  final List<String> dataLimits;
  final String source;
  final String model;

  const AdvisoryData({required this.summary, required this.observations, required this.actions, required this.watchItems, required this.dataLimits, required this.source, required this.model});

  factory AdvisoryData.fromJson(Map<String, dynamic> json) {
    final a=json['advisory'] as Map<String, dynamic>;
    return AdvisoryData(
      summary: a['summary']?.toString() ?? '',
      observations: (a['observations'] as List? ?? []).map((e)=>e.toString()).toList(),
      actions: (a['actions'] as List? ?? []).map((e)=>AdvisoryAction.fromJson(e as Map<String,dynamic>)).toList(),
      watchItems: (a['watch_items'] as List? ?? []).map((e)=>e.toString()).toList(),
      dataLimits: (a['data_limits'] as List? ?? []).map((e)=>e.toString()).toList(),
      source: json['source']?.toString() ?? 'AI',
      model: json['model']?.toString() ?? '',
    );
  }
}

class AdvisoryService {
  final String baseUrl;
  AdvisoryService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  String _condition(int code) {
    if(code==0) return 'Clear sky';
    if(code==1||code==2||code==3) return 'Cloudy or partly cloudy';
    if(code==45||code==48) return 'Fog';
    if(code>=51&&code<=57) return 'Drizzle';
    if(code>=61&&code<=67) return 'Rain';
    if(code>=71&&code<=77) return 'Snow';
    if(code>=80&&code<=82) return 'Rain showers';
    if(code>=85&&code<=86) return 'Snow showers';
    if(code>=95&&code<=99) return 'Thunderstorm';
    return 'Variable conditions';
  }

  Future<AdvisoryData> fetch({
    required String location,
    required String crop,
    required double farmSizeAcres,
    required DateTime sowingDate,
    required WeatherData weather,
    SoilData? soil,
    SatelliteData? satellite,
  }) async {
    final response=await http.post(
      Uri.parse('$baseUrl/advisory'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({
        'location':location,
        'crop':crop,
        'farm_size_acres':farmSizeAcres,
        'sowing_date':sowingDate.toIso8601String().substring(0,10),
        'temperature_c':weather.temperature,
        'humidity_percent':weather.humidity,
        'wind_kmh':weather.windSpeed,
        'rain_probability_percent':weather.rainProbability,
        'weather_condition':_condition(weather.weatherCode),
        'soil_ph':soil?.ph,
        'organic_carbon_g_kg':soil?.organicCarbon,
        'nitrogen_g_kg':soil?.nitrogen,
        'clay_percent':soil?.clay,
        'soil_source':soil?.source,
        'ndvi':satellite?.ndvi,
        'satellite_date':satellite?.observationDate,
        'satellite_cloud_cover_percent':satellite?.cloudCover,
        'satellite_source':satellite?.source,
      }),
    ).timeout(const Duration(seconds:60));
    final json=jsonDecode(response.body) as Map<String,dynamic>;
    if(response.statusCode!=200) throw Exception(json['detail']?.toString()??'AI advisory service failed.');
    return AdvisoryData.fromJson(json);
  }
}
