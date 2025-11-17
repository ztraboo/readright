import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:readright/audio/stt/pronunciation_assessor.dart';
import 'package:path/path.dart' as p;
import 'package:string_similarity/string_similarity.dart';

import '../on_device/cmu_map.dart';

/// Cloud STT Model (https://deepgram.com/learn/introducing-nova-3-speech-to-text-api).

/// Implementations should accept WAV bytes or PCM as required by the vendor.
class DeepgramAssessor implements PronunciationAssessor {
  final String audioPath;
  final String practiceWord;

  // TODO secure api key in storage - firebase security?
  final String apiKey = '4ec2df06384b70fc6d37f3cc1179238f0f67c5c0';
  late String extension = '';


  DeepgramAssessor({
    required this.audioPath,
    required this.practiceWord,
  });

  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale,
  }) async {
    try {
      extension = p.extension(audioPath);
    } catch (e, st) {
      debugPrint('Audio path error: $e\n$st');
      return AssessmentResult(
        recognizedText: '',
        confidence: 0.0,
        score: 0.0,
        details: {'error': e.toString()},
      );
    }

    final uri = Uri.parse('https://api.deepgram.com/v1/listen');
    final headers = {
      'Authorization': 'Token $apiKey',
      'Content-Type': 'audio/$extension',
    };
    try {
      final audioBytes = await File(audioPath).readAsBytes();
      final response = await http.post(uri, headers: headers, body: audioBytes);
      final data = jsonDecode(response.body);

      final transcript = data['results']?['channels']?[0]?['alternatives']?[0]?['transcript'] ?? '';
      final modelConfidence = data['results']?['channels']?[0]?['alternatives']?[0]?['confidence'] ?? 0.0;

      debugPrint("transcript: $transcript");
      return AssessmentResult(
        recognizedText: transcript,
        confidence: modelConfidence,
        score: setScore(transcript, practiceWord),
        details: {
          'timestamp': DateTime.now().toIso8601String(),
          'format': extension,
          'bytes': audioBytes.length,
          'wordCount': transcript
              .trim()
              .split(RegExp(r'\s+'))
              .length,
          'provider': 'Deepgram Nova-3',
          'finalized': true,
        },
      );
    } catch (e, st) {
      debugPrint('DeepgramAssessor REST error: $e\n$st');
      return AssessmentResult(
        recognizedText: '',
        confidence: 0.0,
        score: 0.0,
        details: {'error': e.toString()},
      );
    }
  }

  double setScore(String transcript, String referenceWord){
    double score = 0.0;
    double jaroScore = 0.0;
    double cmuScore = 0.0;

    // Normalize reference text and transcript prior to analysis
    String normReference = normalize(referenceWord);
    String normTranscript = normalize(transcript);

    // Compute Jaro-Winkler score between 0 and 1

    // Analyze each word individually to avoid variability in transcript length
    List<String> words = normTranscript.split(' ');
    double bestScore = 0.0;

    for (String word in words) {
      jaroScore = StringSimilarity.compareTwoStrings(normReference, word);
      debugPrint("word: $word \njaroscore: $jaroScore, \nbestscore: $bestScore");
      if (jaroScore > bestScore) {
        bestScore = jaroScore;
      }
    }
    jaroScore = bestScore;

    // Omit CMUDict assessment if the correct word was spoken
    // CMUDict identifies the difference in phonetic pattern between different words
    // Using the following algorithm on two of the same word is redundant
    if (jaroScore == 1.0){
      cmuScore = 1.0;
    }
    else {
      List<String>? expectedPhonemes = cmuDict[normReference];
      if (expectedPhonemes == null){
        debugPrint("expectedPhonemes is NULL");
      }
      else {
        bestScore = 0.0;
        debugPrint("expectedPhonemes: $expectedPhonemes");
        for (String word in words) {
          List<String>? wordPhonemes = cmuDict[word];
          if (wordPhonemes == null){
            debugPrint("wordPhonemes is NULL for word: $word");
          }
          else {
            debugPrint("comparing word, $word ($wordPhonemes) with $referenceWord ($expectedPhonemes)");
            cmuScore = comparePhonemes(expectedPhonemes, wordPhonemes);
            debugPrint("CMUScore = $cmuScore");
            if (cmuScore > bestScore) {
              bestScore = cmuScore;
            }
          }
        }
        cmuScore = bestScore;
        debugPrint("final cmuScore: $cmuScore");
      }
    }


    // Weigh phonetic pattern higher
    double cmuWeight = 0.7;
    double jaroWeight = 0.3;
    score = (cmuScore * cmuWeight) + (jaroScore* jaroWeight);
    return score;
  }

  // helper to normalize transcript and reference word
  // Drop digits, punctuation, and ensure lower case
  String normalize(String subject) {
    String normalized = subject.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[0-9\p{P}]', unicode: true), '');
    normalized = normalized.trim();
    return normalized;
  }

  // Helper method to compare to lists of phonemes
  double comparePhonemes(List<String> refPhonemes, List<String> actualPhonemes){
    double score = 0.0;

    // compare entries with Levenshtein
    // final refStr = refPhonemes.join(' ');
    // final actualStr = actualPhonemes.join(' ');
    // int distance = Levenshtein.distance(refStr, actualStr);
    int distance = levenshteinList(refPhonemes, actualPhonemes);
    final maxLen = refPhonemes.length > actualPhonemes.length ? refPhonemes.length : actualPhonemes.length;

    if (maxLen == 0){
      debugPrint("Phoneme lists are empty");
      return 0.0;
    }

    score = 1.0 - (distance/maxLen);

    return score;
  }

  // custom Levenshtein implementation to compare lists
  // returns number of incorrect List items
  int levenshteinList<T>(List<String> expectedPhonemes, List<String> actualPhonemes) {
    final expectedLength = expectedPhonemes.length;
    final actualLength = actualPhonemes.length;

    final matrix = List.generate(
      expectedLength + 1,
          (_) => List<int>.filled(actualLength + 1, 0),
    );

    for (var i = 0; i <= expectedLength; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= actualLength; j++) {
      matrix[0][j] = j;
    }

    // Fill the matrix
    for (var i = 1; i <= expectedLength; i++) {
      for (var j = 1; j <= actualLength; j++) {
        final substitutionCost =
        expectedPhonemes[i - 1] == actualPhonemes[j - 1] ? 0 : 1;

        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + substitutionCost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return matrix[expectedLength][actualLength];
  }

}
