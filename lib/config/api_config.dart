import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredUrl = String.fromEnvironment(
    'AGRIN_API_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredUrl.isNotEmpty) {
      return _configuredUrl.replaceAll(RegExp(r'/$'), '');
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://127.0.0.1:8000';
  }
}
