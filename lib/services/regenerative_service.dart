import 'dart:convert';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;

class RegenerativePractice {
  final String title, reason, priority, basis;
  const RegenerativePractice({required this.title,required this.reason,required this.priority,required this.basis});
  factory RegenerativePractice.fromJson(Map<String,dynamic> j)=>RegenerativePractice(title:j['title'].toString(),reason:j['reason'].toString(),priority:j['priority'].toString(),basis:j['basis'].toString());
}
class RegenerativeEvidence {
  final String signal,value,interpretation,source;
  const RegenerativeEvidence({required this.signal,required this.value,required this.interpretation,required this.source});
  factory RegenerativeEvidence.fromJson(Map<String,dynamic> j)=>RegenerativeEvidence(signal:j['signal'].toString(),value:j['value'].toString(),interpretation:j['interpretation'].toString(),source:j['source'].toString());
}
class RegenerativePlan {
  final String source,location,crop;
  final List<String> principles,limitations;
  final List<RegenerativePractice> practices;
  final List<RegenerativeEvidence> evidence;
  const RegenerativePlan({required this.source,required this.location,required this.crop,required this.principles,required this.practices,required this.evidence,required this.limitations});
  factory RegenerativePlan.fromJson(Map<String,dynamic> j)=>RegenerativePlan(
    source:j['source'].toString(),location:j['location'].toString(),crop:j['crop'].toString(),
    principles:(j['principles'] as List? ?? const[]).map((e)=>e.toString()).toList(),
    practices:(j['practices'] as List? ?? const[]).map((e)=>RegenerativePractice.fromJson(e as Map<String,dynamic>)).toList(),
    evidence:(j['evidence'] as List? ?? const[]).map((e)=>RegenerativeEvidence.fromJson(e as Map<String,dynamic>)).toList(),
    limitations:(j['limitations'] as List? ?? const[]).map((e)=>e.toString()).toList(),
  );
}
class RegenerativeService {
  final String baseUrl;
  RegenerativeService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;
  Future<RegenerativePlan> fetch({required String location,required String crop,required double temperature,required double humidity,required int rainProbability,required double ph,required double organicCarbon,required double nitrogen,required double clay,required String soilSource}) async {
    final response=await http.post(Uri.parse('$baseUrl/regenerative/plan'),headers:{'Content-Type':'application/json'},body:jsonEncode({
      'location':location,'crop':crop,'temperature_c':temperature,'humidity_percent':humidity,'rain_probability_percent':rainProbability,
      'soil_ph':ph,'organic_carbon_g_kg':organicCarbon,'nitrogen_g_kg':nitrogen,'clay_percent':clay,'soil_source':soilSource,
    })).timeout(const Duration(seconds:20));
    if(response.statusCode!=200) {
      try { final body=jsonDecode(response.body) as Map<String,dynamic>; throw Exception(body['detail']?.toString() ?? 'Regenerative plan failed.'); }
      catch(_) { throw Exception('Regenerative plan failed (${response.statusCode}).'); }
    }
    return RegenerativePlan.fromJson(jsonDecode(response.body) as Map<String,dynamic>);
  }
}
