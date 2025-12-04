// import 'dart:async';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../audio/stream/pcm_player.dart';
import '../../audio/stt/pronunciation_assessor.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/models/current_user_model.dart';
import 'package:readright/models/class_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/services/class_repository.dart';
import 'package:readright/services/student_progress_repository.dart';
import 'package:readright/services/word_respository.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_scoring.dart';
import '../../utils/app_styles.dart';
import 'package:readright/utils/enums.dart';
import 'package:readright/utils/device_utility.dart';

class StudentWordFeedbackPage extends StatefulWidget {

  const StudentWordFeedbackPage({super.key});

  @override
  State<StudentWordFeedbackPage> createState() => _StudentWordFeedbackPageState();
}

class _StudentWordFeedbackPageState extends State<StudentWordFeedbackPage> {

  late final UserModel? _currentUser;
  late final ClassModel? _currentClassSection;
  late final String? audioPath;
  late final int? audioDurationMS;
  late final AudioCodec? audioCodec;

  WordModel? practiceWord;
  String? practiceSentenceId;
  int? practiceSentenceIndex;
  String? displaySentence = '';
  WordLevel? wordLevel;
  bool hasNextWord = true;

  double _currentScore = 0.0;
  double _passingThresholdStars = 0.0;
  Uint8List? _pcmBytes;
  AssessmentResult? _attemptResult;

  bool _isIntroductionTtsPlaying = false;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();

    // Grab passed arguments from Navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        setState(() {
          _attemptResult = args['attemptResult'] as AssessmentResult?;
          _pcmBytes = args['pcmBytes'] as Uint8List?;
          practiceWord = args['practiceWord'] as WordModel?;
          wordLevel = args['wordLevel'] as WordLevel?;
          audioPath = args['audioPath'] as String?;
          audioDurationMS = args['audioDurationMS'] as int?;
          audioCodec = args['audioCodec'] as AudioCodec?;
        });
      } else if (args is Map) {
        setState(() {
          _attemptResult = args['attemptResult'];
          _pcmBytes = args['pcmBytes'] as Uint8List?;
          practiceWord = args['practiceWord'] as WordModel?;
          wordLevel = args['wordLevel'] as WordLevel?;
          audioPath = args['audioPath'] as String?;
          audioDurationMS = args['audioDurationMS'] as int?;
          audioCodec = args['audioCodec'] as AudioCodec?;
        });
      }

      // Normalize passing threshold score to star rating.
      _normalizeSTTScoreToStars(rawScore: AppScoring.passingThreshold).then((normalized) {
        setState(() {
          debugPrint("StudentWordFeedbackPage: Passing threshold STT score of ${AppScoring.passingThreshold} is represented as ${normalized} stars.");
          _passingThresholdStars = normalized;
        });
      });

      // Normalize score based on attemptResult score value if available.
      // Only normalize if score is greater than zero.
      if (_attemptResult != null && _attemptResult!.score > 0) {
        _normalizeSTTScoreToStars(rawScore: _attemptResult?.score as double).then((normalized) {
          setState(() {
            debugPrint("StudentWordFeedbackPage: Speech-To-Text (STT) score of ${_attemptResult?.score} is represented as ${normalized} stars.");
            _currentScore = normalized;
          });
        });
      }

      setState(() {
        _currentUser = context.read<CurrentUserModel>().user;

        if (_currentUser != null) {
          _currentClassSection = context.read<CurrentUserModel>().classSection;

          debugPrint('StudentWordFeedbackPage: User UID: ${_currentUser!.id}, Username: ${_currentUser!.username}, Email: ${_currentUser!.email}, Role: ${_currentUser!.role.name}, ClassSection: ${_currentClassSection?.id}');

          // Save the attempt record and update student and class progress.
          storeAttempt(
            audioPath: audioPath ?? '',
            audioDurationMS: audioDurationMS ?? 0,
            audioCodec: audioCodec ?? AudioCodec.unknown,
          ).then( (_) {
            // Do nothing for now after storing attempt.
          });
        } else {
          debugPrint('StudentWordFeedbackPage: No persisted user found.');
        }
      });

      // Grab the next sentence for the practice word.
      fetchNewWordSentence();

      // Handle the header TTS.
      // We're only calling this here to ensure it runs after initial state setup.
      // This will not be called again if the user traverse from
      // the student feedback screen back to this practice screen.
      _handleIntroductionTts();
    }); 
  } 

  // Normalize raw score to 0..5 double stars (in 0.5 increments) based on rawScore input of 0..1 or 0..100 percentage value.
  // Returns a double in 0.0..5.0 stepped by 0.5 to represent star count.
  Future<double> _normalizeSTTScoreToStars({double rawScore = 0.0}) async {
    double percent = rawScore;
    // If provided as 0..100, convert to 0..1
    if (percent > 1.0) {
      percent = percent / 100.0;
    }
    // Clamp to valid percentage range
    percent = percent.clamp(0.0, 1.0);

    // Map percentage to 0..5 scale
    final double scaled = percent * 5.0;

    // Round to nearest 0.5
    double rounded = (scaled * 2.0).round() / 2.0;

    // Treat tiny non-zero scores as at least 0.5
    if (percent > 0.0 && rounded == 0.0) rounded = 0.5;

    // Ensure within bounds
    rounded = rounded.clamp(0.0, 5.0) as double;

    return rounded;
  }

  void fetchNewWordSentence() {
      // Select a random sentence index for the practice word
      // Normalize to match filenames
      // Only pick a sentence index if we haven't already set one.
      final word = practiceWord?.text.trim().toLowerCase();
      final idx = (DateTime.now().millisecondsSinceEpoch % 3) + 1;
      debugPrint('StudentWordPracticePage: Selected sentence index: $idx for word: $word');
      setState(() {
        practiceSentenceId = 'sentence_$idx';
        practiceSentenceIndex = idx;
      });
  }

  // Store an attempt record and student progress in Firestore.
  // IMPORTANT: When we did this on the recording screen before navigating to feedback, we received a lag
  // when traversing pages. By moving this to the feedback screen after navigation, the user experience is smoother.
  Future<void> storeAttempt({
    required String audioPath,
    required int audioDurationMS,
    required AudioCodec audioCodec,
  }) async {

    debugPrint("StudentWordPracticePage: Storing attempt record for wordId: ${practiceWord?.id}, audioPath: $audioPath");

    final classId = _currentClassSection?.id ?? '';
    final userId = _currentUser?.id ?? '';
    final wordId = practiceWord?.id ?? '';
    final score = _attemptResult?.score ?? 0.0;

    final attempt = AttemptModel(
      classId: classId,
      userId: userId,
      wordId: wordId,
      speechToTextTranscript: _attemptResult?.recognizedText ?? '',
      audioCodec: audioCodec,
      audioPath: audioPath,
      durationMS: audioDurationMS,
      confidence: _attemptResult?.confidence ?? 0.0,
      score: score,
      devicePlatform: DeviceUtils.getCurrentPlatform(),
      deviceOS: await DeviceUtils.getOsVersion(),
    );

    // Save attempt record to Firestore.
    try {
      await AttemptRepository().upsertAttempt(attempt);
      debugPrint('StudentWordPracticePage: Attempt record added successfully for wordId: $wordId');
    } catch (e) {
      debugPrint('StudentWordPracticePage: Error adding attempt record: $e');
    }

    // Save student progress update to Firestore.
    try {
      final studentProgress = await StudentProgressRepository().fetchProgressByUid(userId);

      await StudentProgressRepository().upsertProgress(
        studentProgress!
          .addAttemptId(attempt.id, wordId: wordId, score: score)
      );

      debugPrint('StudentWordPracticePage: Student progress updated successfully for userId: $userId');
    } catch (e) {
      debugPrint('StudentWordPracticePage: Error updating student progress: $e');
    }

    // Save class progress update to Firestore.
    try {
      // Fetch the current class model since it might have changed between attempts for multiple students.
      _currentClassSection = await ClassRepository().fetchClassById(classId);
      // ignore: use_build_context_synchronously
      context.read<CurrentUserModel>().classSection = _currentClassSection;

      await ClassRepository().upsertClass(
        await _currentClassSection!
          .addAttemptId(wordId: wordId, score: score)
        );
      debugPrint('StudentWordPracticePage: Class progress updated successfully for classId: $classId');
    } catch (e) {
      debugPrint('StudentWordPracticePage: Error updating class progress: $e');
    }
  }

  void _handleRetry() {
    // Navigator.pop(  
    //   context,
    // );
    Navigator.of(
      context,
    ).pushReplacementNamed(
        '/student-word-practice',
        arguments: {
          'practiceWord': practiceWord,
          'wordLevel': wordLevel,
          'retryWord': true,
        });
  }

  final PcmPlayer _pcmPlayer = PcmPlayer();

  Future<void> _handleReplay() async {
    try {
      if (_pcmBytes is Uint8List) {
        await _pcmPlayer.playBufferedPcm(_pcmBytes!, sampleRate: 16000);
        return;
      }
    } catch (e, st) {
      debugPrint('StudentWordFeedbackPage: Error playing PCM via PcmPlayer: $e\n$st');
    }
  }

  Future<void> _handleTts({required String assetPath}) async {
      // Try a small pre-check to ensure the asset exists in the bundle before
    // asking the native audio plugin to play it. This avoids opaque native
    // errors when the asset is missing or wasn't bundled into the app.
    // Asset keys must not start with "./"; use the asset path as declared in
    // pubspec.yaml (e.g. 'assets/audio/...'). Using a leading './' will cause
    // rootBundle.load(...) to fail with "Unable to load asset".

    ByteData assetData;
    try {
      assetData = await rootBundle.load(assetPath);
    } catch (assetErr) {
      debugPrint('StudentWordPracticePage: TTS asset not found: $assetPath, falling back to TTS. Error: $assetErr');
      return;
    }

    // Play using flutter_sound's player (plays from in-memory buffer).
    final player = FlutterSoundPlayer();
    final completer = Completer<void>();
    try {
        try {
          await player.openPlayer();
        } catch (openErr) {
          debugPrint('StudentWordPracticePage: flutter_sound openPlayer failed: $openErr. Falling back to TTS.');
          return;
        }

        try {
          await player.startPlayer(
            fromDataBuffer: assetData.buffer.asUint8List(),
            codec: Codec.mp3,
            whenFinished: () {
            if (!completer.isCompleted) completer.complete();
            },
          );
        } catch (startErr) {
          debugPrint('StudentWordPracticePage: flutter_sound startPlayer failed for $assetPath: $startErr. Falling back to TTS.');
          return;
        }

        // Wait until playback completes (whenFinished completes the completer).
        await completer.future;
      } catch (playErr) {
        debugPrint('StudentWordPracticePage: Asset playback error: $playErr, falling back to TTS.');
        return;
      } finally {
        // Best-effort cleanup. Ignore individual errors but log them.
        try {
          await player.stopPlayer();
        } catch (stopErr) {
          debugPrint('StudentWordPracticePage: Error stopping flutter_sound player: $stopErr');
        }
        try {
          await player.closePlayer();
        } catch (closeErr) {
          debugPrint('Error closing flutter_sound audio session: $closeErr');
        }
      }
  }

  Future<void> _speakTts(String word) async {
    try {
      await flutterTts.setLanguage('en-US');
      await flutterTts.setPitch(1.0);
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.speak(word);
    } catch (e) {
      debugPrint('StudentWordPracticePage: TTS speak failed: $e');
    }
  }

  void _handleIntroductionTts() async {
    setState(() {
      _isIntroductionTtsPlaying = true;
      debugPrint('StudentWordFeedbackPage: Starting introduction TTS... $_isIntroductionTtsPlaying');
    });
    
    // Recite the header to the user on load.
    Future.microtask(() async {
      // Ensure the prompt audio plays first, then the word audio.
      String assetPathScore = AppConstants.assetPathPhrases;

      if (_currentScore >= 0.0 && _currentScore < 2.0) {
        assetPathScore += 'oh_no_lets_try_again.mp3';
      } else if (_currentScore >= 2.0 && _currentScore < 3.5) {
        assetPathScore += 'not_bad_keep_practicing.mp3';
      } else if (_currentScore >= 3.5 && _currentScore < 4.0) {
        assetPathScore += 'good_work_you_passed.mp3';
      } else if (_currentScore >= 4.0 && _currentScore < 5.0) {
        assetPathScore += 'great_job.mp3';
      } else if (_currentScore >= 5.0) {
        assetPathScore += 'excellent_perfect_pronunciation.mp3';
      } else {
        assetPathScore += 'let_us_try_again.mp3';
      }
      
      // Play the let's see how you did, then "for the word", then the word itself, then score message.
      await _handleTts(assetPath: '${AppConstants.assetPathPhrases}lets_see_how_you_did.mp3');
      await _handleTts(assetPath: '${AppConstants.assetPathPhrases}for_the_word.mp3');
      await _handleTts(assetPath: '${AppConstants.assetPathWords}${practiceWord?.text.trim().toLowerCase()}.mp3');
      await _handleTts(assetPath: '${AppConstants.assetPathSentences}${practiceWord?.text.trim().toLowerCase()}_${practiceSentenceId}.mp3');
      await _handleTts(assetPath: assetPathScore);

      // Provide additional guidance based on score (e.g. Next or Retry to continue).
      if (_currentScore >= _passingThresholdStars) {
        // Positive reinforcement for passing score.
        await _handleTts(assetPath: '${AppConstants.assetPathPhrases}click_next_to_continue.mp3');
      } else {
        // Encouragement for low score.
        await _handleTts(assetPath: '${AppConstants.assetPathPhrases}click_retry_to_record_again.mp3');
      }

      setState(() {
        _isIntroductionTtsPlaying = false;
        debugPrint('StudentWordFeedbackPage: Ending introduction TTS... $_isIntroductionTtsPlaying');
      });
      
    });
  }

  @override
  void dispose() {
    _pcmPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 15),
              _buildYetiIllustration(),
              const SizedBox(height: 15),
              _buildSentenceSection(),
              const SizedBox(height: 15),
              _buildStarRating(),
              // _buildTranscriptSection(),
              const SizedBox(height: 15),
              //_buildInstructions(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildReplayButton(),
                  const SizedBox(width: 20),
                  _buildRetryButton(),
                ],
              ),
              const SizedBox(height: 20),
              // Always show the next button even if the user scores low.
              _buildNextButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 214,
      color: AppColors.bgPrimaryGray,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 400,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                      icon: Icon(Icons.account_circle, color: (_isIntroductionTtsPlaying) ? AppColors.bgPrimaryDarkGrey.withOpacity(0.5) : AppColors.buttonPrimaryGray),
                      onPressed: () {
                        if (!_isIntroductionTtsPlaying) {
                          debugPrint("Icon Pressed - navigating to profile settings.");
                          Navigator.pushNamed(
                            context,
                            '/profile-settings',
                          );
                          return;
                        } else {
                          debugPrint("Icon Pressed during TTS playback - ignoring.");
                        }
                      }
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 400,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Let's see how you did for the word",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Compact Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                  // const SizedBox(width: 5),
                  // IconButton(
                  //     icon: const Icon(Icons.account_circle, color: AppColors.buttonPrimaryGray),
                  //     onPressed: () {
                  //       debugPrint("Icon Pressed");
                  //       Navigator.pushNamed(
                  //         context,
                  //         '/profile-settings',
                  //       );
                  //     }
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 30),
                SizedBox(
                  child: Text(
                    '${practiceWord?.text}',
                    textAlign: TextAlign.center,
                    style: AppStyles.headerText.copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                  child: _buildTtsWordButton(),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildYetiIllustration() {
    return SizedBox(
      width: 364,
      height: 350,
      child: _currentScore < _passingThresholdStars ? SvgPicture.asset(
        'assets/mascot/yeti_upset.svg',
        semanticsLabel: 'Yeti Upset',
        fit: BoxFit.contain,
      ) : SvgPicture.asset(
        'assets/mascot/yeti_happy.svg',
        semanticsLabel: 'Yeti Happy',
        fit: BoxFit.contain,
      ),
    );
  }

  // String _scoreMessage() {
  //   if (_currentScore >= 0.0 && _currentScore < 2.0) {
  //     return 'Oh no — let\'s try again!';
  //   } else if (_currentScore >= 2.0 && _currentScore < 3.5) {
  //     return 'Not bad, keep practicing!';
  //   } else if (_currentScore >= 3.5 && _currentScore < 4.0) {
  //     return 'Good work — you passed!';
  //   } else if (_currentScore >= 4.0 && _currentScore < 5.0) {
  //     return 'Great job!';
  //   } else if (_currentScore >= 5.0) {
  //     return 'Excellent! Perfect pronunciation!';
  //   } else {
  //     return 'Let us try again!';
  //   }
  // }

  // Widget _buildSentenceSection() {
  //   return Container(
  //     width: double.infinity,
  //     height: 77,
  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFFFFC6C0).withOpacity(0.20),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       crossAxisAlignment: CrossAxisAlignment.center,
  //       children: [
  //         SvgPicture.asset(
  //           'assets/icons/quote-open-editor-svgrepo-com.svg',
  //           width: 23,
  //           height: 23,
  //           semanticsLabel: 'Quote Open',
  //         ),
  //         const SizedBox(width: 4),
  //         Flexible(
  //           child: Text.rich(
  //             TextSpan(
  //               children: [
  //                 TextSpan(
  //                   text: _scoreMessage(),
  //                   style: TextStyle(
  //                     fontFamily: 'SF Compact Display',
  //                     fontSize: 20,
  //                     fontWeight: FontWeight.w400,
  //                     color: Colors.black,
  //                     height: 1.1,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             textAlign: TextAlign.center,
  //           ),
  //         ),
  //         const SizedBox(width: 4),
  //         SvgPicture.asset(
  //           'assets/icons/quote-close-editor-svgrepo-com.svg',
  //           width: 23,
  //           height: 23,
  //           semanticsLabel: 'Quote Close',
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildHighLightedWordInSentence({
    required String sentence,
    required String wordToHighlight,
    required TextStyle textStyle,
    required TextStyle highlightStyle,
  }) {
    // Guard for empty inputs
    if (sentence.isEmpty || wordToHighlight.trim().isEmpty) {
      return Flexible(
        child: Text(
          sentence,
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      );
    }

    // Build a regex that matches the target word as a whole word, case-insensitive.
    final escaped = RegExp.escape(wordToHighlight.trim());
    final regex = RegExp(r'\b' + escaped + r'\b', caseSensitive: false);

    final matches = regex.allMatches(sentence).toList();

    // If there are no matches, just return the plain sentence.
    if (matches.isEmpty) {
      return Flexible(
        child: Text(
          sentence,
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      );
    }

    // Build TextSpans preserving original casing from the sentence:
    final spans = <TextSpan>[];
    var lastIndex = 0;
    for (final m in matches) {
      if (m.start > lastIndex) {
        spans.add(TextSpan(
          text: sentence.substring(lastIndex, m.start),
          style: textStyle,
        ));
      }
      spans.add(TextSpan(
        text: sentence.substring(m.start, m.end),
        style: highlightStyle,
      ));
      lastIndex = m.end;
    }
    if (lastIndex < sentence.length) {
      spans.add(TextSpan(
        text: sentence.substring(lastIndex),
        style: textStyle,
      ));
    }

    return Flexible(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: spans,
        ),
      ),
    );
  }

  Widget _buildSentenceSection() {
    if (!mounted) return Container();

    return (wordLevel == null)
      ? CircularProgressIndicator()
      : FutureBuilder<dynamic>(
        future: WordRepository().fetchWordByTextAndLevel(
          practiceWord?.text ?? '',
          wordLevel!,
        ),
        builder: (context, snapshot) {
          // debugPrint('StudentWordPracticePage: Word fetch snapshot: ${snapshot.connectionState}, hasData: ${snapshot.hasData}');

          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            try {
              // Offset by -1 to convert 1-based index to 0-based list index for what's stored in the Firestore.
              final sentences = snapshot.data?.sentences;
              if (sentences is List && sentences.length > (practiceSentenceIndex! - 1)) {
                displaySentence = sentences[practiceSentenceIndex! - 1] as String? ?? '';
              }
            } catch (e) {
                displaySentence = '';
            }
          }

          if (displaySentence?.isEmpty ?? true) {
            // Fallback sentence if repository didn't provide one.
            displaySentence = '...';
          }

          return Container(
            width: double.infinity,
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC6C0).withOpacity(0.20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/icons/quote-open-editor-svgrepo-com.svg',
                  width: 23,
                  height: 23,
                  semanticsLabel: 'Quote Open',
                ),
                const SizedBox(width: 4),
                _buildHighLightedWordInSentence(
                  sentence: displaySentence ?? '',
                  wordToHighlight: practiceWord?.text ?? '',
                  textStyle: AppStyles.subheaderText.copyWith(
                    fontSize: 24,
                  ),
                  highlightStyle: AppStyles.subheaderTextBold.copyWith(
                    fontSize: 24,
                  ),
                ),
                const SizedBox(width: 4),
                SvgPicture.asset(
                  'assets/icons/quote-close-editor-svgrepo-com.svg',
                  width: 23,
                  height: 23,
                  semanticsLabel: 'Quote Close',
                ),
                const SizedBox(width: 8),
                _buildTtsWordSentenceButton(),
              ],
            ),
          );
        },
      );
  }

   Widget _buildTtsWordButton() {
    // Disable audio button while recording or processing to prevent cheating.
    return IconButton(
      icon: Icon(Icons.volume_up),
      color: Colors.green,
      iconSize: 40,
      tooltip: 'Play Practice Word',
      onPressed: () {
        _handleTts(assetPath: '${AppConstants.assetPathWords}${practiceWord?.text.trim().toLowerCase()}.mp3');
      },
    );
  }

  Widget _buildTtsWordSentenceButton() {
    // Disable audio button while recording or processing to prevent cheating.
    return IconButton(
      icon: Icon(Icons.volume_up),
      color: Colors.green,
      iconSize: 40,
      tooltip: 'Play Practice Word Sentence',
      onPressed: () {
        _handleTts(assetPath: '${AppConstants.assetPathSentences}${practiceWord?.text.trim().toLowerCase()}_${practiceSentenceId}.mp3');
      },
    );
  } 
  
  Widget _buildStarRating() {
    const int totalStars = 5;

    // Ensure score is within 0..totalStars and round to nearest 0.5
    final double bounded = _currentScore.clamp(0.0, totalStars.toDouble());
    final double roundedScore = (bounded * 2.0).round() / 2.0;

    final int fullStars = roundedScore.floor();
    final bool hasHalf = (roundedScore - fullStars) == 0.5;

    debugPrint("StudentWordFeedbackPage: building star rating for score $_currentScore -> rounded $roundedScore (full=$fullStars half=$hasHalf)");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(totalStars, (index) {
          String asset;
          String semantics;
          if (index < fullStars) {
            asset = 'assets/icons/star-yellow-svgrepo-com.svg';
            semantics = 'Star Yellow';
          } else if (index == fullStars && hasHalf) {
            asset = 'assets/icons/star-yellow-half-svgrepo-com.svg';
            semantics = 'Star Yellow Half';
          } else {
            asset = 'assets/icons/star-gray-svgrepo-com.svg';
            semantics = 'Star Gray';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: SvgPicture.asset(
              asset,
              width: 70,
              height: 70,
              semanticsLabel: semantics,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTranscriptSection() {
    return Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA).withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          _attemptResult != null && _attemptResult!.recognizedText.isNotEmpty
              ? 'You said: "${_attemptResult!.recognizedText}"'
              : 'Your pronunciation will appear here.',
          textAlign: TextAlign.center,
          style: AppStyles.chipText.copyWith(
            fontSize: 20
          ),
        ),
      ),
    );
  }

  Widget _buildReplayButton() {
    return (_isIntroductionTtsPlaying == true)
      ? Container(
          height: 44,
          width: 136,
          decoration: BoxDecoration(
            color: AppColors.bgPrimaryGray,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: const Center(
            child: Text(
              'PLAYBACK',
              style: AppStyles.buttonText,
            ),
          ),
        )
      : GestureDetector(
      onTap: _handleReplay,
      child: Container(
        height: 44,
        width: 136,
        decoration: BoxDecoration(
          color: AppColors.buttonSecondaryRed,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: const Center(
          child: Text(
            'PLAYBACK',
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }

  // Widget _buildInstructions() {
  //   return Container(
  //     width: double.infinity,
  //     height: 86,
  //     padding: const EdgeInsets.all(10),
  //     child: const Center(
  //       child: SizedBox(
  //         width: 360,
  //         child: Text(
  //           'Click retry to try this word again or dashboard to return to the practice word list.',
  //           textAlign: TextAlign.center,
  //           style: TextStyle(
  //             fontFamily: 'SF Compact Display',
  //             fontSize: 16,
  //             fontWeight: FontWeight.w400,
  //             color: Colors.black,
  //             height: 1.375,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildRetryButton() {
    return (_isIntroductionTtsPlaying == true) || (_currentScore >= _passingThresholdStars)
      ? Container(
          height: 44,
          width: 136,
          decoration: BoxDecoration(
            color: AppColors.bgPrimaryGray,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: const Center(
            child: Text(
              'RETRY',
              style: AppStyles.buttonText,
            ),
          ),
        )
      : GestureDetector(
        onTap: _handleRetry,
        child: Container(
          height: 44,
          width: 136,
          decoration: BoxDecoration(
            color: AppColors.buttonPrimaryOrange,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: const Center(
            child: Text(
              'RETRY',
              style: AppStyles.buttonText,
            ),
          ),
        ),
      );
  }

  Widget _buildNextButton() {
    return (_isIntroductionTtsPlaying == true)
      ? Container(
          height: 44,
          width: 160,
          decoration: BoxDecoration(
            color: AppColors.bgPrimaryGray,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: const Center(
            child: Text(
              'NEXT',
              style: AppStyles.buttonText,
            ),
          ),
        )
      : GestureDetector(
      onTap: () async {

        // Let the student word practice page handle fetching the next word and transitioning to the level complete screen.
        Navigator.pushNamed(
          context,
          '/student-word-practice',
          arguments: {
            'wordLevel': wordLevel,
          },
        );

      },
      child: Container(
        height: 44,
        width: 160,
        decoration: BoxDecoration(
          color: (hasNextWord == true ? AppColors.buttonSecondaryGreen : AppColors.buttonPrimaryBlue),
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Center(
          child: Text(
            (hasNextWord == true ? 'NEXT' : 'DASHBOARD'),
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }

}
