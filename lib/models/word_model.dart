
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/firestore_utils.dart';

/// Model class representing a word with its properties.
class WordModel {
  final String id;
  final String text;
  final WordLevel level;
  final int levelOrder;
  final List<String> sentences;

  /// If [id] is omitted, a deterministic id from `text` and `levelName`. will be generated.
  /// Id generation is delegated to [FirestoreUtils].
  WordModel({
    String? id,
    required this.text,
    required this.level,
    required this.levelOrder,
    required this.sentences,
  }) : id = id ?? FirestoreUtils.generateDeterministicWordId(text, level.name); 

  // Create a copy of the current WordModel with optional new values.
  WordModel copyWith({
    String? id,
    String? text,
    WordLevel? level,
    int? levelOrder,
    List<String>? sentences,
  }) {
    return WordModel(
      // make sure id regenerates on content change; this is handled by the constructor.
      text: text ?? this.text,
      level: level ?? this.level,
      levelOrder: levelOrder ?? this.levelOrder,
      sentences: sentences ?? this.sentences,
    );
  }

  // Convert WordModel instance to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'level': level.name,
      'levelOrder': levelOrder,
      'sentences': sentences.toList(),
    };
  }

  // Create a WordModel instance from JSON data retrieved from Firestore.
  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      id: (json['id'] as String?) ?? FirestoreUtils.generateDeterministicWordId(json['text'] as String, json['level'] as String),
      text: json['text'] as String,
      levelOrder: json['levelOrder'] as int,
      level: WordLevel.values.firstWhere(   
        (e) => e.name == json['level'],
        orElse: () => WordLevel.custom,
      ),
      sentences: List<String>.from(json['sentences'] as List<dynamic>),
    );
  } 

}