import '../config/api_config.dart';
import 'api_client.dart';

class FarmTwinData {
  final bool available;
  final String version;
  final String generatedAt;
  final Map<String,dynamic> farm;
  final Map<String,dynamic> state;
  final Map<String,dynamic> semantics;
  final List<dynamic> actions;
  final List<dynamic> limitations;

  const FarmTwinData({required this.available,required this.version,required this.generatedAt,required this.farm,required this.state,required this.semantics,required this.actions,required this.limitations});

  factory FarmTwinData.fromJson(Map<String,dynamic> j)=>FarmTwinData(
    available:j['available']==true,
    version:j['twin_version']?.toString()??'1.0',
    generatedAt:j['generated_at']?.toString()??'',
    farm:(j['farm'] as Map<String,dynamic>?)??{},
    state:(j['state'] as Map<String,dynamic>?)??{},
    semantics:(j['state_semantics'] as Map<String,dynamic>?)??{},
    actions:(j['actions'] as List<dynamic>?)??const[],
    limitations:(j['limitations'] as List<dynamic>?)??const[],
  );
}

class FarmTwinService {
  final String baseUrl;
  FarmTwinService({String? baseUrl}):baseUrl=baseUrl??ApiConfig.baseUrl;

  Future<FarmTwinData> build({required String location,required String crop,double? farmSizeAcres}) async {
    final j = await ApiClient(baseUrl: baseUrl).postJson(
      '/farm-twin/build',
      body:{'location':location,'crop':crop,'farm_size_acres':farmSizeAcres},
      timeout:const Duration(seconds:120),
    );
    return FarmTwinData.fromJson(j);
  }
}
