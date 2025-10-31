import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Utilities to prepare Firestore document data with standard metadata.
class FirestoreMetadata {
  
  /// Returns a copy of [data] with `updatedAt` set to server timestamp.
  /// If [isNew] is true, also sets `createdAt` to server timestamp and
  /// `createdBy` to [uid] or `FirebaseAuth.instance.currentUser?.uid` when
  /// available.
  static Map<String, dynamic> prepareForSave(Map<String, dynamic> data,
      {bool isNew = false, String? uid}) {
    final result = Map<String, dynamic>.from(data);

    // Always set updatedAt
    result['updatedAt'] = FieldValue.serverTimestamp();

    if (isNew) {
      // Prefer provided uid, otherwise try FirebaseAuth (may be null in tests).
      String? createdBy = uid;
      try {
        createdBy ??= FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        // In some test environments FirebaseAuth.instance may not be
        // available; swallow errors and leave createdBy null.
        createdBy = createdBy;
      }
      result['createdBy'] = createdBy;
      result['createdAt'] = FieldValue.serverTimestamp();
    }

    return result;
  }
}
