import 'package:readright/services/user_repository.dart';
import 'package:readright/services/student_progress_repository.dart';
import 'package:readright/utils/app_scoring.dart';
import 'package:readright/utils/firestore_utils.dart';

/// Model class representing a Class entity
class ClassModel {

  // This 'id' value will be the Firestore document ID.
  late final String? id;
  final double averageClassWordAttemptScore;
  late final String? classCode;
  String institution;
  final String teacherId;
  String sectionId;
  List<String> studentIds;
  List<String> wordStruggledIds;
  int totalWordsToComplete;

  ClassModel({
    String? id,
    this.averageClassWordAttemptScore = 0.0,
    String? classCode,
    this.institution = '',
    this.teacherId = '',
    this.sectionId = '',
    this.studentIds = const [],
    this.wordStruggledIds = const [],
    this.totalWordsToComplete = 0,
  }) {
      this.id = id ?? FirestoreUtils.generateDeterministicClassId(institution, teacherId, sectionId);

      // Set classCode as first 6 characters of the document ID
      this.classCode = classCode ?? this.id!.substring(0, 6);

      initializeClassName();

      assert(averageClassWordAttemptScore >= 0.0 && averageClassWordAttemptScore <= 100.0, 'averageClassWordAttemptScore must be between 0.0 and 100.0');
    }

  // Fetch teacher's name for class name if not provided
  Future<void> initializeClassName() async {
    final teacher = await UserRepository().fetchUserByUserUID(teacherId);
    institution = teacher?.institution ?? '';

    // Set default sectionId here. 
    // We're not asking for this on the teacher registration form.
    sectionId = '001'; // Default section ID if not provided
  }

  // Create a copy of the current ClassModel with optional new values.
  ClassModel copyWith({
    String? id,
    double? averageClassWordAttemptScore,
    String? classCode,
    String? institution,
    String? teacherId,
    String? sectionId,
    List<String>? studentIds,
    List<String>? wordStruggledIds,
    int? totalWordsToComplete,
  }) {
    return ClassModel(
      id: id ?? this.id,
      averageClassWordAttemptScore: averageClassWordAttemptScore ?? this.averageClassWordAttemptScore,
      classCode: classCode ?? this.classCode,
      institution: institution ?? this.institution,
      teacherId: teacherId ?? this.teacherId,
      sectionId: sectionId ?? this.sectionId,
      studentIds: studentIds ?? this.studentIds,
      wordStruggledIds: wordStruggledIds ?? this.wordStruggledIds,
      totalWordsToComplete: totalWordsToComplete ?? this.totalWordsToComplete,
    );
  }

  Future<ClassModel> addAttemptId({String? wordId, double score = 0.0}) async {
    final newStruggled = List<String>.from(wordStruggledIds);

    // Round score up to the nearest hundredth.
    score = (score * 100).roundToDouble() / 100.0;

    // Update words struggled IDs if score is low (e.g. below AppScoring.passingThreshold).
    if (score < AppScoring.passingThreshold && wordId != null && wordId.isNotEmpty) {
      if (!newStruggled.contains(wordId)) {
        newStruggled.add(wordId);
      }
    } else if (score >= AppScoring.passingThreshold && wordId != null && wordId.isNotEmpty) {

      int countStudentIdsWithStruggledId = 0;
      // Check if any other student in the class is still struggling with this word
      for (final uid in studentIds) {
        final progress = await StudentProgressRepository().fetchProgressByUid(uid);
        if (progress == null) continue;

        final struggled = progress.wordStruggledIds;

        // If per-student stores a map of wordId -> count
        if (struggled.contains(wordId)) {
          countStudentIdsWithStruggledId += 1;
        }
      }

      // If all students improved, remove wordId from struggled list for the class.
      if (countStudentIdsWithStruggledId == 0) {
        newStruggled.remove(wordId);
      }
    }

    // Calculate the new word average score based on the existing average and new score.
    int countClassWordsAttempted = 0;
    for(final uid in studentIds) {
      final progress = await StudentProgressRepository().fetchProgressByUid(uid);
      if (progress == null) continue;

      countClassWordsAttempted += progress.countWordsAttempted;
    }

    final totalScore = averageClassWordAttemptScore * countClassWordsAttempted + score;
    final newClassAverageWordAttemptScore = countClassWordsAttempted + 1 > 0
        ? totalScore / (countClassWordsAttempted + 1)
        : 0.0;

    return copyWith(
      wordStruggledIds: newStruggled,
      averageClassWordAttemptScore: newClassAverageWordAttemptScore,
    );
  }

  // Create a ClassModel instance from JSON data retrieved from Firestore.
  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: (json['id'] as String?) ?? FirestoreUtils.generateDeterministicClassId(
        json['institution'] as String? ?? '',
        json['teacherId'] as String? ?? '',
        json['sectionId'] as String? ?? '',
      ),
      averageClassWordAttemptScore: (json['averageClassWordAttemptScore'] as num?)?.toDouble() ?? 0.0,
      classCode: json['classCode'] as String? ?? '',
      institution: json['institution'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      studentIds: List<String>.from(json['studentIds'] as List<dynamic>? ?? []),
      wordStruggledIds: List<String>.from(json['wordStruggledIds'] as List<dynamic>? ?? []),
      totalWordsToComplete: json['totalWordsToComplete'] as int? ?? 0,
    );
  }

  // Convert ClassModel instance to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'averageClassWordAttemptScore': averageClassWordAttemptScore,
      'classCode': classCode,
      'institutionId': institution,
      'teacherId': teacherId,
      'sectionId': sectionId,
      'studentIds': studentIds,
      'wordStruggledIds': wordStruggledIds,
      'totalWordsToComplete': totalWordsToComplete,
    };
  }

}