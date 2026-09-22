import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class WaterIntelligenceData {
  final bool available;
  final String source;
  final Map<String,dynamic> summary;
  final List<dynamic> signals;
  final List<dynamic> daily;
  final List<dynamic> decisionSupport;
  final List<dynamic> limitations;

  const WaterIntelligenceData({
    required this.available, required this.source, required this.summary,
    required this.signals, required this.daily, required this.decisionSupport, required this.limitations,
  });

  factory WaterIntelligenceData.fromJson(Map<String,dynamic> j)=>WaterIntelligenceData(
    available:j['available']==true,
    source:j['source']?.toString()??'Water intelligence',
    summary:(j['summary'] as Map<String,dynamic>?)??{},
    signals:(j['signals'] as List<dynamic>?)??const[],
    daily:(j['daily'] as List<dynamic>?)??const[],
    decisionSupport:(j['decision_support'] as List<dynamic>?)??const[],
    limitations:(j['limitations'] as List<dynamic>?)??const[],
  );

  String metric(String key) {
    final v=summary[key];
    if(v==null) return 'Unavailable';
    if(v is num) return v.toStringAsFixed(1);
    return v.toString();
  }
}

class WaterIntelligenceService {
  final String baseUrl;
  WaterIntelligenceService({String? baseUrl}):baseUrl=baseUrl??ApiConfig.baseUrl;

  Future<WaterIntelligenceData> fetch({required double latitude,required double longitude,int forecastDays=7}) async {
    final response=await http.post(
      Uri.parse('$baseUrl/water/intelligence'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'latitude':latitude,'longitude':longitude,'forecast_days':forecastDays}),
    ).timeout(const Duration(seconds:60));
    final json=jsonDecode(response.body) as Map<String,dynamic>;
    if(response.statusCode!=200) throw Exception(json['detail']?.toString()??'Water intelligence failed.');
    return WaterIntelligenceData.fromJson(json);
  }
}
