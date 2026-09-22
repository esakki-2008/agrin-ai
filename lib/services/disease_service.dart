import 'dart:convert';
import '../config/api_config.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DiseaseAnalysis {
  final String assessment;
  final List<String> possibleIssues;
  final List<String> observations;
  final List<DiseaseAction> actions;
  final List<String> limitations;
  final String source;
  final String model;

  DiseaseAnalysis({
    required this.assessment,
    required this.possibleIssues,
    required this.observations,
    required this.actions,
    required this.limitations,
    required this.source,
    required this.model,
  });

  factory DiseaseAnalysis.fromJson(Map<String, dynamic> json) {
    return DiseaseAnalysis(
      assessment: json['assessment']?.toString() ?? 'Assessment unavailable.',
      possibleIssues: List<String>.from(json['possible_issues'] ?? const []),
      observations: List<String>.from(json['observations'] ?? const []),
      actions: (json['actions'] as List? ?? const [])
          .map((x) => DiseaseAction.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      limitations: List<String>.from(json['limitations'] ?? const []),
      source: json['source']?.toString() ?? 'Google Gemini API',
      model: json['model']?.toString() ?? 'gemini-2.5-flash',
    );
  }
}

class DiseaseAction {
  final String title;
  final String reason;
  final String priority;

  DiseaseAction({required this.title, required this.reason, required this.priority});

  factory DiseaseAction.fromJson(Map<String, dynamic> json) {
    return DiseaseAction(
      title: json['title']?.toString() ?? 'Field check',
      reason: json['reason']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'medium',
    );
  }
}

class DiseaseService {
  static String get baseUrl => ApiConfig.baseUrl;

  Future<DiseaseAnalysis> analyze({
    required Uint8List imageBytes,
    required String mimeType,
    String crop = '',
    String location = '',
  }) async {
    final response = await http
        .post(
          Uri.parse('${baseUrl}/disease/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image_base64': base64Encode(imageBytes),
            'mime_type': mimeType,
            'crop': crop,
            'location': location,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['detail']?.toString() ?? 'Crop analysis failed.');
      } catch (_) {
        throw Exception('Crop analysis failed (${response.statusCode}).');
      }
    }

    return DiseaseAnalysis.fromJson(jsonDecode(response.body)['analysis']);
  }
}
