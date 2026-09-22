import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AgriNetworkService {
  final String baseUrl;
  AgriNetworkService({String? baseUrl}):baseUrl=baseUrl??ApiConfig.baseUrl;

  Future<Map<String,dynamic>> manifest() async {
    final r=await http.get(Uri.parse('$baseUrl/network/manifest')).timeout(const Duration(seconds:30));
    final j=jsonDecode(r.body) as Map<String,dynamic>;
    if(r.statusCode!=200) throw Exception(j['detail']?.toString()??'Network manifest unavailable.');
    return j;
  }

  Future<Map<String,dynamic>> packageObservation(Map<String,dynamic> observation) async {
    final r=await http.post(Uri.parse('$baseUrl/network/package'),headers:{'Content-Type':'application/json'},body:jsonEncode({'producer':'AgriN','observation':observation})).timeout(const Duration(seconds:30));
    final j=jsonDecode(r.body) as Map<String,dynamic>;
    if(r.statusCode!=200) throw Exception(j['detail']?.toString()??'Network package failed.');
    return j;
  }
}
