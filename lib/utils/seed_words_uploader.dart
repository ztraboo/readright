import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:readright/models/word_model.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/enums.dart';

/// Utility to load `data/seed_words.csv` (packed as an asset) and upload
/// each row to Firestore using `WordsRepository.upsertWord`.
///
/// Usage:
///   // ensure Firebase.initializeApp() has been called in your app
///   await SeedWordsUploader.uploadFromAsset();
class SeedWordsUploader {
  /// Upload CSV content provided as a string. Useful for tests where
  /// reading from assets isn't convenient. [upsertFn] is called for each
  /// parsed WordModel (defaults to calling WordRepository().upsertWord).
  static Future<void> uploadFromString(
    String csv, {
    Future<void> Function(WordModel word)? upsertFn,
    void Function(int index, int total)? onProgress,
  }) async {
    final lines = csv.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 1) return; // nothing to upload

    final rows = lines.sublist(1); // skip header
    final total = rows.length;
    final doUpsert = upsertFn ?? (() {
      final repo = WordRepository();
      return (WordModel w) => repo.upsertWord(w);
    }());

    var idx = 0;
    for (final line in rows) {
      final fields = _parseCsvLine(line);
      if (fields.isEmpty) {
        idx++;
        if (onProgress != null) onProgress(idx, total);
        continue;
      }

      final text = fields.length > 0 ? fields[0].trim() : '';
      final category = fields.length > 1 ? fields[1].trim() : '';
      final sentences = fields.length > 2
          ? fields.sublist(2).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[];

      if (text.isEmpty) {
        idx++;
        if (onProgress != null) onProgress(idx, total);
        continue;
      }

      final level = _mapCategoryToLevel(category);

      final word = WordModel(
        text: text,
        level: level,
        sentences: sentences,
      );

      await doUpsert(word);

      idx++;
      if (onProgress != null) onProgress(idx, total);
    }
  }

  /// Reads [assetPath], parses CSV rows and uploads each word.
  ///
  /// [onProgress] will be called with (currentIndex, total) after each
  /// successful upsert. The method awaits each upsert so Firestore is
  /// updated sequentially.
  static Future<void> uploadFromAsset({
    String assetPath = 'data/seed_words.csv',
    void Function(int index, int total)? onProgress,
  }) async {
    final csv = await rootBundle.loadString(assetPath);
    await uploadFromString(csv, onProgress: onProgress);
  }

  

  // Map CSV category strings (free-form) to WordLevel enum values.
  static WordLevel _mapCategoryToLevel(String category) {
    final c = category.toLowerCase();
    if (c.contains('sight')) return WordLevel.sightWord;
    if (c.contains('phon')) return WordLevel.phonicsPattern;
    if (c.contains('minimal')) return WordLevel.minimalPairs;
    return WordLevel.custom;
  }

  // A minimal CSV line parser that supports quoted fields and escaped
  // double-quotes ("" -> "). This is intentionally small and tailored
  // to the project's seed CSV; it's not a full CSV library replacement.
  static List<String> _parseCsvLine(String line) {
    final List<String> fields = [];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        // Handle escaped quote "" inside a quoted field
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}
