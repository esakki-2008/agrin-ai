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

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android Emulator cannot reach the host machine through localhost.
        // For a physical Android device, pass --dart-define=AGRIN_API_URL=...
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:8000';
      case TargetPlatform.fuchsia:
        return 'http://127.0.0.1:8000';
    }
  }

  static Uri endpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized');
  }
}
