import 'package:readright/services/user_repository.dart';
import 'package:readright/utils/firestore_utils.dart';

/// Model class representing a Class entity
class ClassModel {

  // This 'id' value will be the Firestore document ID.
  late final String? id;
  final double classAverage;
  late final String? classCode;
  String institution;
  final String teacherId;
  String sectionId;
  List<String> studentIds;
  List<String> topStrugglingWords;
  int totalWordsToComplete;

  ClassModel({
    String? id,
    this.classAverage = 0.0,
    String? classCode,
    this.institution = '',
    this.teacherId = '',
    this.sectionId = '',
    this.studentIds = const [],
    this.topStrugglingWords = const [],
    this.totalWordsToComplete = 0,
  }) {
      this.id = id ?? FirestoreUtils.generateDeterministicClassId(institution, teacherId, sectionId);

      // Set classCode as first 6 characters of the document ID
      this.classCode = classCode ?? this.id!.substring(0, 6);

      initializeClassName();

      assert(classAverage >= 0.0 && classAverage <= 100.0, 'classAverage must be between 0.0 and 100.0');
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
    double? classAverage,
    String? classCode,
    String? institution,
    String? teacherId,
    String? sectionId,
    List<String>? studentIds,
    List<String>? topStrugglingWords,
    int? totalWordsToComplete,
  }) {
    return ClassModel(
      id: id ?? this.id,
      classAverage: classAverage ?? this.classAverage,
      classCode: classCode ?? this.classCode,
      institution: institution ?? this.institution,
      teacherId: teacherId ?? this.teacherId,
      sectionId: sectionId ?? this.sectionId,
      studentIds: studentIds ?? this.studentIds,
      topStrugglingWords: topStrugglingWords ?? this.topStrugglingWords,
      totalWordsToComplete: totalWordsToComplete ?? this.totalWordsToComplete,
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
      classAverage: (json['classAverage'] as num?)?.toDouble() ?? 0.0,
      classCode: json['classCode'] as String? ?? '',
      institution: json['institution'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      studentIds: List<String>.from(json['studentIds'] as List<dynamic>? ?? []),
      topStrugglingWords: List<String>.from(json['topStrugglingWords'] as List<dynamic>? ?? []),
      totalWordsToComplete: json['totalWordsToComplete'] as int? ?? 0,
    );
  }

  // Convert ClassModel instance to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classAverage': classAverage,
      'classCode': classCode,
      'institutionId': institution,
      'teacherId': teacherId,
      'sectionId': sectionId,
      'studentIds': studentIds,
      'topStrugglingWords': topStrugglingWords,
      'totalWordsToComplete': totalWordsToComplete,
    };
  }

}