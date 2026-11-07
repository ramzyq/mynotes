import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mynotes/core/error/error_handler.dart';
import 'package:mynotes/features/capture/services/capture_exception.dart';

class OcrService {
  OcrService({ImagePicker? picker, TextRecognizer? recognizer})
      : _picker = picker ?? ImagePicker(),
        _recognizer = recognizer ?? TextRecognizer();

  final ImagePicker _picker;
  final TextRecognizer _recognizer;

  /// The text in a photo the user takes or picks: null if they cancelled,
  /// '' if the photo has no readable text. Throws
  /// [CaptureUnavailableException] with a message to show otherwise.
  Future<String?> pickAndRecognizeText({required bool fromCamera}) async {
    final XFile? image;
    try {
      image = await _picker.pickImage(source: fromCamera ? ImageSource.camera : ImageSource.gallery);
    } on PlatformException catch (e, stack) {
      // iOS reports a refused permission; Android's picker intents need none.
      if (e.code == 'camera_access_denied') {
        throw const CaptureUnavailableException(
          'Notely needs camera access to scan text. Turn it on in Settings.',
          needsSettings: true,
        );
      }
      if (e.code == 'photo_access_denied') {
        throw const CaptureUnavailableException(
          'Notely needs photo access to scan text. Turn it on in Settings.',
          needsSettings: true,
        );
      }
      AppErrorHandler().handle(e, stack);
      throw CaptureUnavailableException(
        fromCamera ? "Couldn't open the camera." : "Couldn't open your photos.",
      );
    }
    if (image == null) return null;

    try {
      final recognized = await _recognizer.processImage(InputImage.fromFilePath(image.path));
      return recognized.text.trim();
    } catch (error, stack) {
      AppErrorHandler().handle(error, stack);
      throw const CaptureUnavailableException("Couldn't read text from that photo.");
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
