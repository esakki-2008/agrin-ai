import 'api_client.dart';
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
    final json = await ApiClient(baseUrl: baseUrl).postJson(
      '/water/intelligence',
      body: {'latitude':latitude,'longitude':longitude,'forecast_days':forecastDays},
      timeout: const Duration(seconds:60),
    );
    return WaterIntelligenceData.fromJson(json);
  }
}
