// import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../audio/stream/pcm_player.dart';
import '../../audio/stt/pronunciation_assessor.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/services/user_repository.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/enums.dart';    

class StudentWordFeedbackPage extends StatefulWidget {

  const StudentWordFeedbackPage({super.key});

  @override
  State<StudentWordFeedbackPage> createState() => _StudentWordFeedbackPageState();
}

class _StudentWordFeedbackPageState extends State<StudentWordFeedbackPage> {

  late final UserModel? _currentUser;
  String? practiceWord = '';
  WordLevel? wordLevel;
  bool hasNextWord = true;

  int _currentScore = 0;
  Uint8List? _pcmBytes;
  AssessmentResult? _attemptResult;

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
          practiceWord = args['practiceWord'] as String?;
          wordLevel = args['wordLevel'] as WordLevel?;
        });
      } else if (args is Map) {
        setState(() {
          _attemptResult = args['attemptResult'];
          _pcmBytes = args['pcmBytes'] as Uint8List?;
          practiceWord = args['practiceWord'] as String?;
          wordLevel = args['wordLevel'] as WordLevel?;
        });
      }

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
    }); 

    UserRepository().fetchCurrentUser().then((user) {
      _currentUser = user;

      if (_currentUser == null) {
        debugPrint(
          'StudentWordFeedbackPage: No user is currently signed in.',
        );
      } else {
        debugPrint(
          'StudentWordFeedbackPage: User UID: ${_currentUser.id}, Username: ${_currentUser.username}, Email: ${_currentUser.email}, Role: ${_currentUser.role.name}',
        );
      }
    })
    .catchError((error) {
      debugPrint('Error fetching current user: $error');
    });

  } 

  // Normalize raw score to 0..5 integer stars based on rawScore input of 0..1 or 0..100 pecentage value.
  // Returns integer in 0..5 range to represent star count.
  Future<int> _normalizeSTTScoreToStars({double rawScore = 0.0}) async {
    final rawScoreValue = rawScore;
    // Normalize to a 0.0 - 1.0 percentage (handle values in 0..1 or 0..100)
    double percent = 0.0;
    if (rawScoreValue is num) {
    percent = rawScoreValue.toDouble();
    } else {
    percent = double.tryParse(rawScoreValue?.toString() ?? '') ?? 0.0;
    }
    if (percent > 1.0) {
    // assume value was 0..100, convert to 0..1
    percent = percent / 100.0;
    }
    // Map percentage to 0..5 stars, rounding to nearest integer.
    int mapped = (percent * 5).round();
    // Treat tiny non-zero scores as at least 1 star
    if (percent > 0 && mapped == 0) mapped = 1;
    mapped = max(0, min(5, mapped));
    return mapped;
  }

  void _handleRetry() {
    Navigator.pop(  
      context,
    );
  }

  final PcmPlayer _pcmPlayer = PcmPlayer();

  Future<void> _handleReplay() async {
    try {
      if (_pcmBytes is Uint8List) {
        await _pcmPlayer.playBufferedPcm(_pcmBytes!, sampleRate: 16000);
        return;
      }
    } catch (e, st) {
      debugPrint('Error playing PCM via PcmPlayer: $e\n$st');
    }
  }

  @override
  void dispose() {
    _pcmPlayer.dispose();
    super.dispose();
  }

  void _handleDashboard() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/student-word-dashboard',
      (Route<dynamic> route) => false,
    );
  }

  Future<String?> _fetchUsersNextWord(WordLevel wordLevel) async {
    // Compute the next word for the user to practice in the given word level.
    // This implementation awaits the user's attempts so the local variable is initialized
    // before being used, and avoids unnecessary null-coalescing on word text.

    try {
      // Fetch attempts for the current user from the database (await so userAttempts is initialized).
      final List<AttemptModel> userAttempts = await AttemptRepository().fetchAttemptsByUser(
        _currentUser?.id ?? '',
        classId: 'cXEZyKGck7AHvcP6Abvn',
      );
      debugPrint('Fetched ${userAttempts.length} attempts for user ${_currentUser?.id}');

      final words = await WordRepository().fetchLevelWords(wordLevel);
      // Map to word text; use whereType to filter out any nulls if text is nullable.
      final wordTexts = words.map((w) => w.text).whereType<String>().toList();

      if (wordTexts.isEmpty) return '';
      if (userAttempts.isEmpty) return wordTexts.first;

      // Find the first word that the user has not yet attempted.
      final practiceWord = wordTexts.firstWhere(
        (word) {
          final attemptsForWord = userAttempts.where((a) => a.wordId == word);
          // Select the word if there are no attempts yet.
          return attemptsForWord.isEmpty;
        },
        orElse: () => wordTexts.first,
      );
      debugPrint('Selected next word for level ${wordLevel.name}: $practiceWord');
      return practiceWord;
    } catch (e) {
      debugPrint('Error fetching next word for level ${wordLevel.name}: $e');
      return '';
    }
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
              const SizedBox(height: 19),
              _buildYetiIllustration(),
              const SizedBox(height: 18),
              _buildSentenceSection(),
              // const SizedBox(height: 0),
              _buildStarRating(),
              const SizedBox(height: 12),
              _buildTranscriptSection(),
              const SizedBox(height: 12),
              //_buildInstructions(),
              _buildReplayButton(),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRetryButton(),
                  const SizedBox(width: 20),
                  _buildDashboardNextButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 170,
      color: AppColors.bgPrimaryGray,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(
              width: 349,
              child: Text(
                "Results for pronouncing",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Compact Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 19),
            SizedBox(
              width: 349,
              child: Text(
                practiceWord ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 0.61,
                ),
              ),
            ),
            const SizedBox(height: 31),
          ],
        ),
      ),
    );
  }

  Widget _buildYetiIllustration() {
    return SizedBox(
      width: 364,
      height: 371,
      child: _currentScore <= 2 ? SvgPicture.asset(
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

  String _scoreMessage() {
    switch (_currentScore) {
      case 1:
        return 'Oh no — let\'s try again!';
      case 2:
        return 'Not bad, keep practicing!';
      case 3:
        return 'Good work!';
      case 4:
        return 'Great job!';
      case 5:
        return 'Excellent! Perfect pronunciation!';
      default:
        return 'Let us try again!';
    }
  }

  Widget _buildSentenceSection() {
    return Container(
      width: double.infinity,
      height: 77,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _scoreMessage(),
                    style: TextStyle(
                      fontFamily: 'SF Compact Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          SvgPicture.asset(
            'assets/icons/quote-close-editor-svgrepo-com.svg',
            width: 23,
            height: 23,
            semanticsLabel: 'Quote Close',
          ),
        ],
      ),
    );
  }
  
  Widget _buildStarRating() {
    // Simple visual star rating; use the 'score' passed into this widget for filled stars.
    const int totalStars = 5;

    // Map incoming score to a 0..totalStars range:
    // - If score is between 0 and totalStars, treat it as a direct star count.
    final int raw = _currentScore;
    debugPrint("StudentWordFeedbackPage: building star rating for score $raw");
    int filledCount = 0;
    if (raw >= 0 && raw <= totalStars) {
      filledCount = raw;
    } 

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(totalStars, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: SvgPicture.asset(
              index < filledCount
                  ? 'assets/icons/star-yellow-svgrepo-com.svg'
                  : 'assets/icons/star-gray-svgrepo-com.svg',
              width: 60,
              height: 60,
              semanticsLabel: index < filledCount
                  ? 'Star Yellow'
                  : 'Star Gray',
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
          style: AppStyles.chipText,
        ),
      ),
    );
  }

  Widget _buildReplayButton() {
    return GestureDetector(
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
            'REPLAY',
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
    return GestureDetector(
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

  Widget _buildDashboardNextButton() {
    return GestureDetector(
      onTap: () async {
        // Fetch the next word for the user at the current word level.
        // TODO: Need to put this in the init() method and store 
        // state rather than calling it here potentially on a tap.
        (_fetchUsersNextWord(wordLevel as WordLevel)).then((word) {
          debugPrint('Next word for user ${_currentUser?.id} at level ${wordLevel?.name} is: $word');
          if (word != null && word.isNotEmpty) {
            Navigator.pushNamed(
              context,
              '/student-word-practice',
              arguments: {
                'practiceWord': word,
                'wordLevel': wordLevel,
              },
            );
          } else {
            setState(() {
              hasNextWord = false;
            });
          
            _handleDashboard();
          }
        });
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
