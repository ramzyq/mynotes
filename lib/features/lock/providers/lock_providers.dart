import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/features/lock/services/lock_service.dart';

final lockServiceProvider = Provider<LockService>((ref) {
  return LockService();
});

final unlockedNotesProvider = StateProvider<Set<String>>((ref) {
  return {};
});
