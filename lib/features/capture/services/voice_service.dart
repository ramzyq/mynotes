import 'package:mynotes/features/capture/services/capture_exception.dart';
import 'package:permission_handler/permission_handler.dart';
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

  /// Ask for the microphone. Throws [CaptureUnavailableException] if it is
  /// refused; transcription is optional (recording works without it).
  Future<void> requestPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) status = await Permission.microphone.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      throw const CaptureUnavailableException(
        'Microphone access is blocked for Notely.',
        needsSettings: true,
      );
    }
    if (!status.isGranted) {
      throw const CaptureUnavailableException('Microphone permission was not granted.');
    }
  }

  Future<void> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/voice_notes/';
    await Directory(path).create(recursive: true);
    final filePath = '$path${DateTime.now().millisecondsSinceEpoch}.m4a';
    _transcription = null;

    try {
      final available = await _speech.initialize();
      if (available) {
        await _speech.listen(
          onResult: (result) {
            _transcription = result.recognizedWords;
          },
          // No localeId: the device's language, not always US English.
          listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.dictation),
        );
      }
      await _recorder.start(const RecordConfig(), path: filePath);
      // Only now is there a recording to stop.
      _recordedFilePath = filePath;
    } catch (_) {
      // Don't leave speech recognition holding the microphone.
      await _speech.cancel().catchError((Object _) {});
      _recordedFilePath = null;
      _transcription = null;
      rethrow;
    }
  }

  /// Stop and return the recording. A transcription failure only costs the
  /// text: the audio file is still returned.
  Future<VoiceResult?> stopRecordingAndTranscribe() async {
    final filePath = _recordedFilePath;
    if (filePath == null) return null;
    try {
      await _recorder.stop();
    } finally {
      // Whatever happens, this recording is over.
      _recordedFilePath = null;
      if (_speech.isListening) {
        await _speech.stop().catchError((Object _) {});
      }
    }
    final transcription = _transcription ?? '';
    _transcription = null;
    return VoiceResult(transcription: transcription, filePath: filePath);
  }

  String? get recordedFilePath => _recordedFilePath;

  void dispose() {
    _recorder.dispose();
  }
}
