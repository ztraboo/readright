import 'package:readright/models/attempt_model.dart';
import 'package:readright/utils/app_scoring.dart';

/// Model representing student progress statistics stored in Firestore.
///
/// - `wordAttemptIds` is a List<String> represents AttemptModel IDs (attempt document ids).
/// - Internally the model maintains a Set<String> of completed word IDs (wordId)
///   derived from attempts when attempt data is available.
class StudentProgressModel {
  /// Average score for the student (e.g. 92.0)
  final double averageWordAttemptScore;

  /// Internal list of Attempt IDs (AttemptModel document IDs). When serialized to Firestore this
  /// is stored as a list of AttemptModel.id strings (document references).
  final List<String> wordAttemptIds;

  /// Internal unique set of completed word IDs (derived from AttemptModel.wordId).
  final Set<String> _wordsCompleted;

    /// Returns a list view of the internally-tracked unique completed word IDs.
  List<String> get wordsCompleted => _wordsCompleted.toList();

  /// Distinct count of completed words (derived from the unique set).
  int get countWordsCompleted => _wordsCompleted.length;

  /// References to word document IDs the student struggled with.
  final List<String> wordStruggledIds;

  /// Running count of total word attempts (explicit counter stored in Firestore).
  final int countWordsAttempted;

  /// FirebaseAuth UID for the student.
  final String uid;

  StudentProgressModel({
    this.averageWordAttemptScore = 0.0,
    List<String>? wordAttemptIds,
    List<String>? wordStruggledIds,
    this.countWordsAttempted = 0,
    required this.uid,
    List<String>? wordCompletedIds,
  })  : wordAttemptIds = wordAttemptIds ?? const <String>[],
        wordStruggledIds = wordStruggledIds ?? const <String>[],
        _wordsCompleted = Set<String>.from(wordCompletedIds ?? const <String>[]);

  /// Return a new model with an appended attempt ID.
  ///
  /// Optionally supply `wordId` so the completed-word set can be updated
  /// immediately without needing the full AttemptModel record.
  StudentProgressModel addAttemptId(String attemptId, {String? wordId, double score = 0.0}) {
    final newAttempts = List<String>.from(wordAttemptIds)..add(attemptId);
    final newCompleted = Set<String>.from(_wordsCompleted);

    // Round score up to the nearest hundredth.
    score = (score * 100).roundToDouble() / 100.0;

    // Update words struggled IDs if score is low (e.g. below AppScoring.passingThreshold).
    final struggledIds = List<String>.from(wordStruggledIds);
    if (score < AppScoring.passingThreshold && wordId != null && wordId.isNotEmpty) {
      if (!struggledIds.contains(wordId)) {
        struggledIds.add(wordId);
      }
    } else if (score >= AppScoring.passingThreshold && wordId != null && wordId.isNotEmpty) {
      // If the student improved, remove from struggled list.
      struggledIds.remove(wordId);

      // Only mark word as completed if score is passing.
      newCompleted.add(wordId);
    }

    // Calculate the new word average score based on the existing average and new score.
    final totalScore = averageWordAttemptScore * countWordsAttempted + score;
    final newAverageWordAttemptScore = countWordsAttempted + 1 > 0
        ? totalScore / (countWordsAttempted + 1)
        : 0.0;

    return StudentProgressModel(
      averageWordAttemptScore: newAverageWordAttemptScore,
      wordAttemptIds: newAttempts,
      wordStruggledIds: List<String>.from(struggledIds),
      countWordsAttempted: countWordsAttempted + 1,
      uid: uid,
      wordCompletedIds: newCompleted.toList(),
    );
  }

  /// Convert to JSON for Firestore. Uses common keys:
  /// - 'wordAttemptIds' (list of Attempt IDs)
  /// - 'countWordsAttempted' (number)
  /// - 'completed' (distinct completed count)
  Map<String, dynamic> toJson() {
    return {
      'wordAttemptIds': wordAttemptIds,
      'averageWordAttemptScore': averageWordAttemptScore,
      'countWordsAttempted': countWordsAttempted,
      'countWordsCompleted': countWordsCompleted,
      'wordCompletedIds': _wordsCompleted.toList(),
      'wordStruggledIds': wordStruggledIds,
      'uid': uid,
      // Note: we purposely do not persist the `_wordsCompleted` set as a list
      // by default to avoid duplication; if you want to persist completed word IDs,
      // add a key (e.g. 'wordCompletedIds') here.
    };
  }

  /// Create an instance from Firestore JSON
  factory StudentProgressModel.fromJson(Map<String, dynamic> json) {
    final attemptsRaw =
        json['wordAttemptIds'] ?? json['wordAttemptIds'] ?? const [];
    final wordAttemptIds = List<String>.from(attemptsRaw as List<dynamic>);

    final wordStruggledIdsRaw = json['wordStruggledIds'] ?? const [];
    final wordStruggledIds = List<String>.from(wordStruggledIdsRaw as List<dynamic>);

    final wordCompletedIdsRaw = json['wordCompletedIds'] ?? const [];
    final wordCompletedIds = List<String>.from(wordCompletedIdsRaw as List<dynamic>? ?? []);

    return StudentProgressModel(
      averageWordAttemptScore: (json['averageWordAttemptScore'] as num?)?.toDouble() ?? 0.0,
      wordAttemptIds: wordAttemptIds,
      wordStruggledIds: wordStruggledIds,
      countWordsAttempted: json['countWordsAttempted'] as int? ?? 0,
      uid: json['uid'] as String? ?? '',
      wordCompletedIds: wordCompletedIds,
    );
  }

  // Copy helper
  StudentProgressModel copyWith({
    double? averageWordAttemptScore,
    List<String>? wordAttemptIds,
    List<String>? wordsStruggled,
    int? countWordsAttempted,
    String? uid,
    List<String>? wordCompletedIds,
  }) {
    return StudentProgressModel(
      averageWordAttemptScore: averageWordAttemptScore ?? this.averageWordAttemptScore,
      wordAttemptIds: wordAttemptIds ?? List<String>.from(this.wordAttemptIds),
      wordStruggledIds: wordsStruggled ?? List<String>.from(this.wordStruggledIds),
      countWordsAttempted: countWordsAttempted ?? this.countWordsAttempted,
      uid: uid ?? this.uid,
      wordCompletedIds: wordCompletedIds ?? _wordsCompleted.toList(),
    );
  }

}