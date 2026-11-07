import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mynotes/features/capture/services/capture_exception.dart';
import 'package:mynotes/features/capture/services/ocr_service.dart';

class _MockPicker extends Mock implements ImagePicker {}

class _MockRecognizer extends Mock implements TextRecognizer {}

void main() {
  late _MockPicker picker;
  late _MockRecognizer recognizer;
  late OcrService service;

  setUpAll(() {
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(InputImage.fromFilePath('x'));
  });

  setUp(() {
    picker = _MockPicker();
    recognizer = _MockRecognizer();
    service = OcrService(picker: picker, recognizer: recognizer);
  });

  void pickReturns(XFile? file) =>
      when(() => picker.pickImage(source: any(named: 'source'))).thenAnswer((_) async => file);

  test('a cancelled pick returns null', () async {
    pickReturns(null);
    expect(await service.pickAndRecognizeText(fromCamera: true), isNull);
  });

  test('a photo without text returns an empty string, not null', () async {
    pickReturns(XFile('photo.jpg'));
    when(() => recognizer.processImage(any())).thenAnswer((_) async => RecognizedText(text: '  \n', blocks: const []));
    expect(await service.pickAndRecognizeText(fromCamera: false), '');
  });

  test('refused camera access asks the user to open Settings', () async {
    when(() => picker.pickImage(source: any(named: 'source')))
        .thenThrow(PlatformException(code: 'camera_access_denied'));
    await expectLater(
      service.pickAndRecognizeText(fromCamera: true),
      throwsA(isA<CaptureUnavailableException>().having((e) => e.needsSettings, 'needsSettings', isTrue)),
    );
  });

  test('a recognizer failure becomes a message, not an unhandled error', () async {
    pickReturns(XFile('photo.jpg'));
    when(() => recognizer.processImage(any())).thenThrow(PlatformException(code: 'mlkit'));
    await expectLater(
      service.pickAndRecognizeText(fromCamera: false),
      throwsA(isA<CaptureUnavailableException>().having((e) => e.needsSettings, 'needsSettings', isFalse)),
    );
  });
}
