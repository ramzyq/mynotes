import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/capture/services/location_service.dart';
import 'package:mynotes/features/capture/services/ocr_service.dart';
import 'package:mynotes/features/capture/services/voice_service.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
