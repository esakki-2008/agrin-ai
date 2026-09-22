import 'dart:convert';
import 'package:http/http.dart' as http;

class AgentData {
  final String agent;
  final String version;
  final String generatedAt;
  final Map<String,dynamic> evidence;
  final Map<String,dynamic> report;
  final List<String> sources;

  const AgentData({required this.agent,required this.version,required this.generatedAt,required this.evidence,required this.report,required this.sources});

  factory AgentData.fromJson(Map<String,dynamic> j)=>AgentData(
    agent:j['agent']?.toString()??'AgriN Farm Intelligence Agent',
    version:j['version']?.toString()??'',
    generatedAt:j['generated_at']?.toString()??'',
    evidence:Map<String,dynamic>.from(j['evidence'] as Map? ?? {}),
    report:Map<String,dynamic>.from(j['report'] as Map? ?? {}),
    sources:(j['sources'] as List? ?? []).map((e)=>e.toString()).toList(),
  );
}

class AgentService {
  final String baseUrl;
  const AgentService({this.baseUrl='http://127.0.0.1:8000'});

  Future<AgentData> analyze({required String location,required String crop,double? farmSizeAcres,int historicalDays=30}) async {
    final response=await http.post(Uri.parse('$baseUrl/agent/analyze'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'location':location,'crop':crop,'farm_size_acres':farmSizeAcres,'historical_days':historicalDays}),
    ).timeout(const Duration(seconds:120));
    final body=jsonDecode(response.body) as Map<String,dynamic>;
    if(response.statusCode!=200) throw Exception(body['detail']?.toString()??'Farm Intelligence Agent failed.');
    return AgentData.fromJson(body);
  }
}
