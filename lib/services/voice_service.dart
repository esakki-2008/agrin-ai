import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;

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

    _initialized = available;
    return available;
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    String localeId = 'en_IN',
  }) async {
    if (!_initialized) {
      final available = await initialize();
      if (!available) {
        throw Exception('Speech recognition is unavailable.');
      }
    }

    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: localeId),
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

    await _tts.setLanguage(language);
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
