import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final String location;
  final double latitude;
  final double longitude;
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double precipitation;
  final int rainProbability;
  final int weatherCode;
  final String time;
  const WeatherData({required this.location,required this.latitude,required this.longitude,required this.temperature,required this.humidity,required this.windSpeed,required this.precipitation,required this.rainProbability,required this.weatherCode,required this.time});
  factory WeatherData.fromJson(Map<String,dynamic> json,String location) {
    final current=json['current'] as Map<String,dynamic>;
    return WeatherData(location:location,latitude:(json['latitude'] as num).toDouble(),longitude:(json['longitude'] as num).toDouble(),temperature:(current['temperature_2m'] as num).toDouble(),humidity:(current['relative_humidity_2m'] as num).toDouble(),windSpeed:(current['wind_speed_10m'] as num).toDouble(),precipitation:(current['precipitation'] as num).toDouble(),rainProbability:(((json['hourly'] as Map<String,dynamic>)['precipitation_probability'] as List).first as num).toInt(),weatherCode:(current['weather_code'] as num).toInt(),time:current['time'].toString());
  }
}
class WeatherService {
  static final Map<String, ({DateTime expires, WeatherData data})> _cache = {};
  static const _cacheDuration = Duration(minutes: 10);

  Future<WeatherData> fetch(String place) async {
    final key = place.trim().toLowerCase();
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expires)) {
      return cached.data;
    }
    final queries = <String>[
      place.trim(),
      if (!place.contains(',')) place.trim() + ', Maharashtra, India',
      if (!place.contains(',')) place.trim() + ', India',
    ];

    Map<String,dynamic>? item;
    for (final query in queries) {
      final geoUri=Uri.https('geocoding-api.open-meteo.com','/v1/search',{
        'name':query,'count':'5','language':'en','format':'json','countryCode':'IN'
      });
      final geoResponse=await http.get(geoUri).timeout(const Duration(seconds:10));
      if (geoResponse.statusCode != 200) continue;
      final geo=jsonDecode(geoResponse.body) as Map<String,dynamic>;
      final results=(geo['results'] as List?) ?? const [];
      if (results.isEmpty) continue;

      final ranked = results.whereType<Map<String,dynamic>>().toList()
        ..sort((a,b) {
          int score(Map<String,dynamic> x) {
            final country=(x['country_code']?.toString().toUpperCase() == 'IN') ? 0 : 10;
            final state=(x['admin1']?.toString().toLowerCase().contains('maharashtra') ?? false) ? 0 : 1;
            return country + state;
          }
          return score(a).compareTo(score(b));
        });
      if (ranked.isNotEmpty) {
        item=ranked.first;
        break;
      }
    }

    if(item==null) throw Exception('Location not found in India.');
    final resolvedItem=item!;
    final lat=(resolvedItem['latitude'] as num).toDouble(), lon=(resolvedItem['longitude'] as num).toDouble();
    final resolved=[resolvedItem['name'],resolvedItem['admin1'],resolvedItem['country']].where((x)=>x!=null&&x.toString().isNotEmpty).join(', ');
    final weatherUri=Uri.https('api.open-meteo.com','/v1/forecast',{
      'latitude':lat.toString(),'longitude':lon.toString(),
      'current':'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m','hourly':'precipitation_probability','forecast_hours':'1','timezone':'auto'
    });
    final weatherResponse=await http.get(weatherUri).timeout(const Duration(seconds:10));
    if(weatherResponse.statusCode!=200) throw Exception('Weather service failed.');
    final data = WeatherData.fromJson(
      jsonDecode(weatherResponse.body) as Map<String,dynamic>,
      resolved,
    );
    _cache[key] = (expires: DateTime.now().add(_cacheDuration), data: data);
    return data;
  }
}
