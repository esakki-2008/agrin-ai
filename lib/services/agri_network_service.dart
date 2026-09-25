import '../config/api_config.dart';
import 'api_client.dart';

class AgriNetworkService {
  final String baseUrl;
  AgriNetworkService({String? baseUrl}):baseUrl=baseUrl??ApiConfig.baseUrl;

  Future<Map<String,dynamic>> manifest() async {
    return ApiClient(baseUrl:baseUrl).getJson('/network/manifest',timeout:const Duration(seconds:30));
  }

  Future<Map<String,dynamic>> packageObservation(Map<String,dynamic> observation) async {
    return ApiClient(baseUrl:baseUrl).postJson(
      '/network/package',
      body:{'producer':'AgriN','observation':observation},
      timeout:const Duration(seconds:30),
    );
  }
}
