import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Small utility helpers used by Firestore-backed models.
class FirestoreUtils {
  
  /// Generate a deterministic id from `classId`, `userId`, and `wordId`.
  ///
  /// This uses SHA-256 over the string `<classId>|<userId>|<wordId>` and returns the
  /// hex digest. The result is stable across runs for the same inputs.
  static String generateDeterministicAttemptId(String classId, String userId, String wordId) {
    final input = '$classId|$userId|$wordId';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a deterministic id from `text` and `levelName`.
  ///
  /// This uses SHA-256 over the string `<levelName>|<text>` and returns the
  /// hex digest. The result is stable across runs for the same inputs.
  static String generateDeterministicWordId(String text, String levelName, {String? namespace}) {
    final input = '${namespace ?? ''}|$levelName|$text';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

}
