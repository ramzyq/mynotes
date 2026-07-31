import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/capture/services/ocr_service.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});
