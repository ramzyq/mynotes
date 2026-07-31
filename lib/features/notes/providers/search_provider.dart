import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mynotes/core/providers/providers.dart';

final searchResultsProvider = FutureProvider.family<List<String>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final db = ref.watch(databaseProvider);
  return db.searchNotes('current-user', query);
});
