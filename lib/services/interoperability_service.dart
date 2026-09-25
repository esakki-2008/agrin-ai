import '../config/api_config.dart';
import 'api_client.dart';

class InteroperabilityProfile {
  final String standard;
  final String version;
  final String format;
  final List<String> design;
  final List<String> observationGroups;
  final List<String> privacy;

  const InteroperabilityProfile({required this.standard,required this.version,required this.format,required this.design,required this.observationGroups,required this.privacy});
}

class InteroperabilityService {
  static String get baseUrl => ApiConfig.baseUrl;

  Future<InteroperabilityProfile> profile() async {
    final body=await const ApiClient().getJson('/interoperability/profile',timeout:const Duration(seconds:30));
    return InteroperabilityProfile(
      standard:body['standard'].toString(),
      version:body['version'].toString(),
      format:body['format'].toString(),
      design:(body['design'] as List).map((x)=>x.toString()).toList(),
      observationGroups:(body['observation_groups'] as List).map((x)=>x.toString()).toList(),
      privacy:(body['privacy'] as List).map((x)=>x.toString()).toList(),
    );
  }

  Future<Map<String,dynamic>> export({
    required String countryCode,required String locationName,required double latitude,required double longitude,required String observedAt,
    Map<String,dynamic>? weather,Map<String,dynamic>? soil,Map<String,dynamic>? satellite,String? crop,
  }) async {
    return const ApiClient().postJson(
      '/interoperability/export',
      body:{
        'country_code':countryCode,'location_name':locationName,'latitude':latitude,'longitude':longitude,
        'observed_at':observedAt,'weather':weather,'soil':soil,'satellite':satellite,'crop':crop,
      },
      timeout:const Duration(seconds:60),
    );
  }

  Future<Map<String,dynamic>> validateObservation(Map<String,dynamic> observation) async {
    return const ApiClient().postJson('/interoperability/validate',body:observation,timeout:const Duration(seconds:30));
  }

  Future<Map<String,dynamic>> validate({
    required String countryCode,required String locationName,required double latitude,required double longitude,required String observedAt,String? crop,
  }) async {
    return const ApiClient().postJson(
      '/interoperability/validate',
      body:{
        'country_code':countryCode,'location_name':locationName,'latitude':latitude,'longitude':longitude,
        'observed_at':observedAt,'crop':crop,
      },
      timeout:const Duration(seconds:30),
    );
  }
}
