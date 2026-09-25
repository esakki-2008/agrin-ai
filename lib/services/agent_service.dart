import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

class AgentData {
  final String agent;
  final String version;
  final String generatedAt;
  final Map<String,dynamic> evidence;
  final Map<String,dynamic> report;
  final List<String> sources;

  const AgentData({required this.agent,required this.version,required this.generatedAt,required this.evidence,required this.report,required this.sources});

  factory AgentData.fromJson(Map<String,dynamic> j) {
    final rawReport = Map<String,dynamic>.from(j['report'] as Map? ?? {});
    final parsedReport = rawReport['report'] is Map
        ? Map<String,dynamic>.from(rawReport['report'] as Map)
        : rawReport;
    return AgentData(
      agent:j['agent']?.toString()??'AgriN Farm Intelligence Agent',
      version:j['version']?.toString()??'',
      generatedAt:j['generated_at']?.toString()??'',
      evidence:Map<String,dynamic>.from(j['evidence'] as Map? ?? {}),
      report:parsedReport,
      sources:(j['sources'] as List? ?? []).map((e)=>e.toString()).toList(),
    );
  }
}

class AgentService {
  final String baseUrl;
  AgentService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<AgentData> analyze({required String location,required String crop,double? farmSizeAcres,int historicalDays=30}) async {
    final body = await ApiClient(baseUrl: baseUrl).postJson(
      '/agent/analyze',
      body:{'location':location,'crop':crop,'farm_size_acres':farmSizeAcres,'historical_days':historicalDays},
      timeout:const Duration(seconds:120),
    );
    return AgentData.fromJson(body);
  }
}
