import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/capture/services/location_service.dart';
import 'package:mynotes/features/capture/services/ocr_service.dart';
import 'package:mynotes/features/capture/services/voice_service.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
