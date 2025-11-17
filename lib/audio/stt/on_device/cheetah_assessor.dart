import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:cheetah_flutter/cheetah.dart';

import 'package:readright/audio/stream/pcm_recorder.dart';
import 'package:readright/audio/stt/pronunciation_assessor.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:readright/audio/stt/on_device/cmu_map.dart';

// import 'package:collection/collection.dart';


/// On-device assessor for Cheetah (https://picovoice.ai/platform/cheetah/). 
/// Implement provider-specific logic here.
/// Implementations should accept WAV bytes or PCM as required by the vendor.

/// A lightweight local assessor that subscribes to a [PcmRecorder]'s
/// `pcmStream` and computes simple transcription metrics for pronounced word.
class CheetahAssessor implements PronunciationAssessor {
  String accessKey = 'ptQzT1bn5rGVtfHhjX/fUqqamdgh+Q0C1apku5C90SCpt81J5aRGdw==';  // AccessKey obtained from Picovoice Console (https://console.picovoice.ai/)
  String modelPath = 'data/Cheetah_ReadRight.pv'; // path relative to the assets folder or absolute path to file on device

  Cheetah? _cheetah;

  final PcmRecorder pcmRecorder;
  final String practiceWord;

  // CheetahAssessor({this.smoothing = 0.2});
  CheetahAssessor({
    required this.pcmRecorder,
    required this.practiceWord,
  });

  Future<void> createCheetah() async {
    try {
      _cheetah = await Cheetah.create(accessKey, modelPath);
    } catch (err) {
      // handle Cheetah init error
      debugPrint('CheetahAssessor: failed to initialize Cheetah: $err');
    }
  }

  /// Start listening to [recorder]'s `pcmStream` and emit assessment events.
  ///
  /// Calling start multiple times will cancel an existing subscription first.
  Future<void> start() async {
    // Initialize Cheetah instance
    await createCheetah();
  }

  @override
  Future<AssessmentResult> assess({
    required String referenceText,
    required Uint8List audioBytes,
    required String locale
  }) async {
    // Cheetah specific logic to process audioBytes and return an AssessmentResult.
    String transcript = '';
    int framesProcessed = 0;

    if (audioBytes.isEmpty) {
      throw ArgumentError('CheetahAssessor.assess: audioBytes is empty');
    }

    // Ensure Cheetah is initialized.
    if (_cheetah == null) {
      await createCheetah();
      if (_cheetah == null) {
        throw StateError('Cheetah instance could not be initialized');
      }
    }

    // Convert raw PCM bytes (little-endian 16-bit) to Int16List view.
    final samples = PcmRecorder.bytesToInt16List(audioBytes);

    // Cheetah requires frames of a fixed length; process the samples in chunks
    // of that frame length and pad the final frame with zeros if necessary.
    final int frameLength = _cheetah!.frameLength;
    int offset = 0;

    while (offset + frameLength <= samples.length) {
      final frame = Int16List.fromList(samples.sublist(offset, offset + frameLength));
      CheetahTranscript partialResult = await _cheetah!.process(frame);
      transcript += partialResult.transcript;
      framesProcessed++;
      offset += frameLength;
    }

    final int remaining = samples.length - offset;
    if (remaining > 0) {
      final padded = Int16List(frameLength);
      for (int i = 0; i < remaining; i++) {
        padded[i] = samples[offset + i];
      }
      CheetahTranscript partialResult = await _cheetah!.process(padded);
      transcript += partialResult.transcript;
      framesProcessed++;
    }

    // Ensure we flush the model to retrieve any remaining transcript buffered
    // internally by Cheetah (some streaming STT engines only return final text
    // on a flush/finalize call).
    try {
      final CheetahTranscript finalResult = await _cheetah!.flush();
      if (finalResult.transcript.isNotEmpty) {
        if (transcript.isNotEmpty && !transcript.endsWith(' ')) {
          transcript = '$transcript ';
        }
        transcript += finalResult.transcript;

        debugPrint("----------------------------------------------------");
        debugPrint('CheetahAssessor: transcript="$transcript"');
        debugPrint("----------------------------------------------------");
      }
    } catch (err) {
      debugPrint('CheetahAssessor: flush error: $err');
    }


    double confidence = 0.0;
    double score = 0.0;
    double jaroScore = 0.0;
    double cmuScore = 0.0;

    // Normalize reference text and transcript prior to analysis
    String normReference = normalize(referenceText);
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
          debugPrint("comparing word, $word ($wordPhonemes) with $referenceText ($expectedPhonemes)");
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

    // TODO: compute confidence and score

    double cmuWeight = 0.7;
    double jaroWeight = 0.3;
    score = (cmuScore * cmuWeight) + (jaroScore* jaroWeight);
    debugPrint("score before return: $score");
    // Generate a random score between 0.0 and 1.0 with two decimal places.
    // Make sure to update this calculate based on Levenshtein distance calculation.
    // score = double.parse((Random().nextInt(101) / 100).toStringAsFixed(2));


    return AssessmentResult(
      recognizedText: transcript,
      confidence: confidence,
      score: score,
      details: {
        'source': 'cheetah_full_assess',
        'timestamp': DateTime.now().toIso8601String(),
        'frames': framesProcessed,
      },
    );
  }

  /// Dispose resources; after this the instance should not be used.
  Future<void> dispose() async {
    await _cheetah?.delete();
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
