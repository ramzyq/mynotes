import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VoiceResult {
  final String transcription;
  final String filePath;

  VoiceResult({required this.transcription, required this.filePath});
}

class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String? _recordedFilePath;
  String? _transcription;

  Future<bool> requestPermission() async {
    return await _speech.initialize();
  }

  Future<void> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/voice_notes/';
    await Directory(path).create(recursive: true);
    final filePath = '$path${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordedFilePath = filePath;
    _transcription = null;

    final available = await _speech.initialize();
    if (available) {
      await _speech.listen(
        onResult: (result) {
          _transcription = result.recognizedWords;
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'en_US',
          listenMode: stt.ListenMode.dictation,
        ),
      );
    }

    await _recorder.start(const RecordConfig(), path: filePath);
  }

  Future<VoiceResult?> stopRecordingAndTranscribe() async {
    if (_recordedFilePath == null) return null;

    await _recorder.stop();

    if (_speech.isListening) {
      await _speech.stop();
    }

    final transcription = _transcription ?? '';
    final filePath = _recordedFilePath!;
    _recordedFilePath = null;
    _transcription = null;

    return VoiceResult(
      transcription: transcription,
      filePath: filePath,
    );
  }

  String? get recordedFilePath => _recordedFilePath;

  void dispose() {
    _recorder.dispose();
  }
}
