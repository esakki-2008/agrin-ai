import 'package:flutter/foundation.dart';
import 'app_language.dart';

class LanguageController extends ChangeNotifier {
  AppLanguage _language = supportedLanguages.first;
  AppLanguage get language => _language;
  void setLanguage(AppLanguage language) { if (_language.code == language.code) return; _language = language; notifyListeners(); }
}

final languageController = LanguageController();
