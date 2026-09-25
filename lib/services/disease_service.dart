import 'dart:convert';
import 'dart:typed_data';
import '../config/api_config.dart';
import 'api_client.dart';

class DiseaseAnalysis {
  final String assessment;
  final String imageQuality;
  final String imageQualityReason;
  final String evidenceStrength;
  final List<String> possibleIssues;
  final List<String> observations;
  final List<DiseaseAction> actions;
  final List<String> limitations;
  final List<String> followUpQuestions;
  final String source;
  final String model;

  DiseaseAnalysis({required this.assessment,required this.imageQuality,required this.imageQualityReason,required this.evidenceStrength,required this.possibleIssues,required this.observations,required this.actions,required this.limitations,required this.followUpQuestions,required this.source,required this.model});

  factory DiseaseAnalysis.fromJson(Map<String,dynamic> json)=>DiseaseAnalysis(
    assessment:json['assessment']?.toString()??'Assessment unavailable.',
    imageQuality:(json['image_quality'] is Map ? (json['image_quality']['status']?.toString()??'unknown') : 'unknown'),
    imageQualityReason:(json['image_quality'] is Map ? (json['image_quality']['reason']?.toString()??'') : ''),
    evidenceStrength:json['evidence_strength']?.toString()??'unknown',
    possibleIssues:List<String>.from(json['possible_issues']??const[]),
    observations:List<String>.from(json['observations']??const[]),
    actions:(json['actions'] as List? ?? const[]).map((x)=>DiseaseAction.fromJson(Map<String,dynamic>.from(x))).toList(),
    limitations:List<String>.from(json['limitations']??const[]),
    followUpQuestions:List<String>.from(json['follow_up_questions']??const[]),
    source:json['source']?.toString()??'Google Gemini API',
    model:json['model']?.toString()??'gemini-2.5-flash',
  );
}

class DiseaseAction {
  final String title;
  final String reason;
  final String priority;
  DiseaseAction({required this.title,required this.reason,required this.priority});
  factory DiseaseAction.fromJson(Map<String,dynamic> json)=>DiseaseAction(title:json['title']?.toString()??'Field check',reason:json['reason']?.toString()??'',priority:json['priority']?.toString()??'medium');
}

class DiseaseService {
  static String get baseUrl=>ApiConfig.baseUrl;

  Future<DiseaseAnalysis> analyze({required Uint8List imageBytes,required String mimeType,String crop='',String location=''}) async {
    final body=await const ApiClient().postJson(
      '/disease/analyze',
      body:{
        'image_base64':base64Encode(imageBytes),
        'mime_type':mimeType,
        'crop':crop,
        'location':location,
      },
      timeout:const Duration(seconds:60),
    );
    return DiseaseAnalysis.fromJson(body['analysis'] as Map<String,dynamic>);
  }
}
