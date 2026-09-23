import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  List<LocaleName> _speechLocales = const [];

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(dynamic error)? onError,
  }) async {
    if (_initialized) return true;

    final available = await _speech.initialize(
      onStatus: onStatus,
      onError: onError,
    );

    if (available) {
      _speechLocales = await _speech.locales();
    }

    _initialized = available;
    return available;
  }

  String? _matchSpeechLocale(String requested) {
    if (_speechLocales.isEmpty) return requested;

    final normalized = requested.replaceAll('_', '-').toLowerCase();
    final exact = _speechLocales.where(
      (locale) => locale.id.replaceAll('_', '-').toLowerCase() == normalized,
    );
    if (exact.isNotEmpty) return exact.first.id;

    final language = normalized.split('-').first;
    final sameLanguage = _speechLocales.where(
      (locale) => locale.id.replaceAll('_', '-').toLowerCase().split('-').first == language,
    );
    if (sameLanguage.isNotEmpty) return sameLanguage.first.id;

    return null;
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    String localeId = 'en-IN',
  }) async {
    if (!_initialized) {
      final available = await initialize();
      if (!available) {
        throw Exception('Speech recognition is unavailable.');
      }
    }

    final resolvedLocale = _matchSpeechLocale(localeId);
    if (resolvedLocale == null) {
      throw Exception('Speech recognition for $localeId is not available on this device/browser.');
    }

    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: resolvedLocale),
      onResult: (result) {
        onResult(result.recognizedWords);
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> speak(
    String text, {
    String language = 'en-IN',
  }) async {
    if (text.trim().isEmpty) return;

    final availableLanguages = await _tts.getLanguages;
    final normalized = language.replaceAll('_', '-').toLowerCase();

    String? resolvedLanguage;
    for (final item in availableLanguages) {
      final value = item.toString();
      if (value.replaceAll('_', '-').toLowerCase() == normalized) {
        resolvedLanguage = value;
        break;
      }
    }

    if (resolvedLanguage == null) {
      final languageOnly = normalized.split('-').first;
      for (final item in availableLanguages) {
        final value = item.toString();
        if (value.replaceAll('_', '-').toLowerCase().split('-').first == languageOnly) {
          resolvedLanguage = value;
          break;
        }
      }
    }

    if (resolvedLanguage == null) {
      throw Exception('Text-to-speech for $language is not available on this device/browser.');
    }

    await _tts.setLanguage(resolvedLanguage);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _speech.stop();
    await _tts.stop();
  }
}
