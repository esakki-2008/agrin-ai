import 'dart:convert';
import 'package:http/http.dart' as http;

class HistoricalDay {
  final String date;
  final double? temperature;
  final double? precipitation;
  final double? et0;
  const HistoricalDay({required this.date, required this.temperature, required this.precipitation, required this.et0});
}

class HistoricalSummary {
  final double? averageTemperature;
  final double? totalPrecipitation;
  final double? averageEt0;
  final String temperatureTrend;
  const HistoricalSummary({required this.averageTemperature, required this.totalPrecipitation, required this.averageEt0, required this.temperatureTrend});
}

class HistoricalWeather {
  final String source;
  final String startDate;
  final String endDate;
  final HistoricalSummary summary;
  final List<HistoricalDay> daily;
  const HistoricalWeather({required this.source, required this.startDate, required this.endDate, required this.summary, required this.daily});
}

class HistoricalScene {
  final String? id;
  final String? datetime;
  final double? cloudCover;
  const HistoricalScene({required this.id, required this.datetime, required this.cloudCover});
}

class HistoricalSatellite {
  final String source;
  final int count;
  final List<HistoricalScene> scenes;
  const HistoricalSatellite({required this.source, required this.count, required this.scenes});
}

class HistoricalService {
  static const baseUrl = 'http://127.0.0.1:8000';

  Future<HistoricalWeather> weather({required double latitude, required double longitude, int days = 30}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/historical/weather'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'latitude': latitude, 'longitude': longitude, 'days': days}),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) throw Exception(_detail(response));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final summary = body['summary'] as Map<String, dynamic>;
    final period = body['period'] as Map<String, dynamic>;
    final daily = (body['daily'] as List).cast<Map<String, dynamic>>();

    return HistoricalWeather(
      source: body['source'].toString(),
      startDate: period['start'].toString(),
      endDate: period['end'].toString(),
      summary: HistoricalSummary(
        averageTemperature: (summary['average_temperature_c'] as num?)?.toDouble(),
        totalPrecipitation: (summary['total_precipitation_mm'] as num?)?.toDouble(),
        averageEt0: (summary['average_daily_et0_mm'] as num?)?.toDouble(),
        temperatureTrend: summary['temperature_trend'].toString(),
      ),
      daily: daily.map((x) => HistoricalDay(
        date: x['date'].toString(),
        temperature: (x['temperature_mean_c'] as num?)?.toDouble(),
        precipitation: (x['precipitation_mm'] as num?)?.toDouble(),
        et0: (x['et0_mm'] as num?)?.toDouble(),
      )).toList(),
    );
  }

  Future<HistoricalSatellite> satelliteScenes({required double latitude, required double longitude, int days = 90}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/historical/satellite-scenes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'latitude': latitude, 'longitude': longitude, 'days': days}),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) throw Exception(_detail(response));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final scenes = (body['scenes'] as List).cast<Map<String, dynamic>>();

    return HistoricalSatellite(
      source: body['source'].toString(),
      count: (body['count'] as num).toInt(),
      scenes: scenes.map((x) => HistoricalScene(
        id: x['id']?.toString(),
        datetime: x['datetime']?.toString(),
        cloudCover: (x['cloud_cover_percent'] as num?)?.toDouble(),
      )).toList();
  }

  String _detail(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    return 'Historical intelligence request failed (' + response.statusCode.toString() + ').';
  }
}
