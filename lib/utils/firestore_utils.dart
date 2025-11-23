import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Small utility helpers used by Firestore-backed models.
class FirestoreUtils {
  
  /// Generate a deterministic id from `classId`, `userId`, `wordId`, and `audioPath`.
  ///
  /// This uses SHA-256 over the string `<classId>|<userId>|<wordId>|<audioPath>|` and returns the
  /// hex digest. The result is stable across runs for the same inputs.
  static String generateDeterministicAttemptId(String classId, String userId, String wordId, String audioPath) {
    final input = '$classId|$userId|$wordId|$audioPath';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a deterministic id from `institution`, `teacherId`, and `sectionId`.
  ///
  /// This uses SHA-256 over the string `<institution>|<teacherId>|<sectionId>` and returns the
  /// hex digest. The result is stable across runs for the same inputs.
  static String generateDeterministicClassId(String institution, String teacherId, String sectionId) {
    final input = '$institution|$teacherId|$sectionId';
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

  static Future<void> renameCollection(String oldName, String newName) async {
    final oldRef = FirebaseFirestore.instance.collection(oldName);
    final newRef = FirebaseFirestore.instance.collection(newName);

    final snap = await oldRef.get();

    for (final doc in snap.docs) {
      await newRef.doc(doc.id).set(doc.data());
      await oldRef.doc(doc.id).delete();
    }
  }

}
