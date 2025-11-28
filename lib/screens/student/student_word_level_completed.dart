import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:readright/models/current_user_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/utils/app_colors.dart';
import 'package:readright/utils/app_constants.dart';
import 'package:readright/utils/app_styles.dart';
import 'package:readright/utils/enums.dart';

class StudentWordLevelCompletedPage extends StatefulWidget {
  const StudentWordLevelCompletedPage({Key? key}) : super(key: key);

  @override
  State<StudentWordLevelCompletedPage> createState() =>
      _StudentWordLevelCompletedPageState();
}

class _StudentWordLevelCompletedPageState extends State<StudentWordLevelCompletedPage>
    with SingleTickerProviderStateMixin {

  UserModel? _currentUser;
  WordLevel? wordLevel;
  WordModel? nextPracticeWord;

  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();

    // Grab passed arguments from Navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        setState(() {
          wordLevel = args['wordLevel'] as WordLevel? ?? WordLevel.prePrimer;
          nextPracticeWord = args['nextPracticeWord'] as WordModel?;

          _currentUser = context.read<CurrentUserModel>().user;

          if (_currentUser != null) {
            debugPrint('StudentWordLevelCompletedPage: User UID: ${_currentUser!.id}, Username: ${_currentUser?.username}, Email: ${_currentUser!.email}, Role: ${_currentUser?.role.name}');
          } else {
            debugPrint('StudentWordLevelCompletedPage: No persisted user found.');
          }
        });
      }
    });

    // Simple celebratory pulse animation for the badge
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.08).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_controller);

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _playConfetti();
 
    // play once after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Handle TTS playback from asset file.
  Future<void> _handleTts({required String assetPath, Duration? duration}) async {
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
      debugPrint('StudentWordLevelCompletedPage: TTS asset not found: $assetPath, falling back to TTS. Error: $assetErr');
      return;
    }

    // Play using flutter_sound's player (plays from in-memory buffer).
    final player = FlutterSoundPlayer();
    final completer = Completer<void>();
    try {
        try {
          await player.openPlayer();
        } catch (openErr) {
          debugPrint('StudentWordLevelCompletedPage: flutter_sound openPlayer failed: $openErr. Falling back to TTS.');
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
          debugPrint('StudentWordLevelCompletedPage: flutter_sound startPlayer failed for $assetPath: $startErr. Falling back to TTS.');
          return;
        }

        // Wait until playback completes (whenFinished completes the completer).
        Timer? stopTimer;
        Timer? mountedCheckTimer;
        try {
          // If a duration was provided, schedule a forced stop after that duration.
          if (duration != null) {
            stopTimer = Timer(duration, () async {
              try {
          await player.stopPlayer();
              } catch (stopErr) {
          debugPrint('StudentWordLevelCompletedPage: Error stopping player after duration: $stopErr');
              } finally {
          if (!completer.isCompleted) completer.complete();
              }
            });
          }

          // Periodically check whether the widget has been disposed; if so, stop the player.
          // This ensures playback is halted promptly when dispose() is called.
          mountedCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (t) async {
            if (!mounted) {
              t.cancel();
              try {
          await player.stopPlayer();
              } catch (stopErr) {
          debugPrint('StudentWordLevelCompletedPage: Error stopping player during dispose: $stopErr');
              } finally {
          if (!completer.isCompleted) completer.complete();
              }
            }
          });

          // Wait for normal completion or one of the stop paths to complete the completer.
          await completer.future;
        } finally {
          stopTimer?.cancel();
          mountedCheckTimer?.cancel();
        }
      } catch (playErr) {
        debugPrint('StudentWordLevelCompletedPage: Asset playback error: $playErr, falling back to TTS.');
        return;
      } finally {
        // Best-effort cleanup. Ignore individual errors but log them.
        try {
          await player.stopPlayer();
        } catch (stopErr) {
          debugPrint('StudentWordLevelCompletedPage: Error stopping flutter_sound player: $stopErr');
        }
        try {
          await player.closePlayer();
        } catch (closeErr) {
          debugPrint('Error closing flutter_sound audio session: $closeErr');
        }
      }
  }

  void _playConfetti() async {
    _confettiController.play();
    
    if (context.read<CurrentUserModel>().currentWordLevel == null) {
      // Game over sound sequence
      _handleTts(assetPath: '${AppConstants.assetPathEffects}pixabay/orchestral-win-331233.mp3');
      _handleTts(assetPath: '${AppConstants.assetPathEffects}pixabay/fireworks-01-419018.mp3');
      await Future.delayed(Duration(seconds: 8));
      await _handleTts(assetPath: '${AppConstants.assetPathPhrases}game_over_you_did_it_congratulations.mp3');
      await _handleTts(assetPath: '${AppConstants.assetPathEffects}pixabay/interface-124464.mp3');
    } else {
      // Level complete sound sequence}
      _handleTts(assetPath: '${AppConstants.assetPathEffects}pixabay/fireworks-13-419033.mp3');
      _handleTts(assetPath: '${AppConstants.assetPathEffects}pixabay/fire-sounds-405444.mp3');
      await Future.delayed(Duration(seconds: 2));
      await _handleTts(assetPath: '${AppConstants.assetPathPhrases}level_complete_nice_work.mp3');
      await _handleTts(assetPath: '${AppConstants.assetPathPhrases}click_next_level_to_practice_more_words.mp3');
    }
  }

  @override
  Widget build(BuildContext context) {

    // final levelName = wordLevel?.name.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFFFC6C0),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 18),
          child: Column(
            children: [
              // Confetti overlay
              // Top center rain
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  blastDirection: 3.14 / 2 * 3, // direction in radians
                  emissionFrequency: 0.9,
                  numberOfParticles: 5,
                  maxBlastForce: 25,
                  minBlastForce: 5,
                  gravity: 0.4,
                  colors: const [
                    AppColors.buttonPrimaryOrange,
                    AppColors.buttonPrimaryBlue,
                    AppColors.buttonSecondaryRed,
                    AppColors.progressMicrophoneBackground
                  ], // <- only use these colors
                ),
              ),

              const SizedBox(height: 100),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF7498C4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (context.read<CurrentUserModel>().currentWordLevel == null)
                    ? 'GAME OVER'
                    : 'LEVEL COMPLETE',
                  style: AppStyles.headerText.copyWith(
                    color: Colors.white,
                    // fontSize: 28,`
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Text(
              //   'You completed $completed of $total words for',
              //   style: AppStyles.subheaderText,
              //   textAlign: TextAlign.center,
              // ),
              // const SizedBox(height: 6),
              // Text(
              //   levelName,
              //   style: AppStyles.headerText,
              //   textAlign: TextAlign.center,
              // ),
              const SizedBox(height: 25),
              _buildYetiIllustration(),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF303030).withOpacity(0.90),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Nice work, ',
                          style: AppStyles.subheaderText.copyWith(
                            color: Colors.white
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentUser != null
                              ? '${_currentUser?.username}!'
                              : '!',
                          style: AppStyles.subheaderText.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (context.read<CurrentUserModel>().currentWordLevel == null)
                        ? 'You did it, congratulations!'
                        : 'Click next level to practice more words.',
                      style: AppStyles.chipText.copyWith(
                        color: Colors.white
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              // const Spacer(),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 100),
                child: Row(
                  children: [
                    (context.read<CurrentUserModel>().currentWordLevel == null)
                      ? SizedBox.shrink()
                      : Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // If caller provided a nextPracticeWord object, navigate directly to practice.
                          if (nextPracticeWord != null) {
                            Navigator.pushNamed(
                              context,
                              '/student-word-practice',
                              arguments: {
                                'practiceWord': nextPracticeWord,
                                'wordLevel': wordLevel,
                              },
                            );
                          } else {
                            // Fallback: go to dashboard where user can pick next list.
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/student-word-dashboard',
                              (Route<dynamic> route) => false,
                            );
                          }
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.buttonPrimaryOrange,
                            borderRadius: BorderRadius.circular(1000),
                          ),
                          child: const Center(
                            child: Text('NEXT LEVEL', style: AppStyles.buttonText),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildYetiIllustration() {
    return SizedBox(
      width: 364,
      height: 300,
      child: 
        (context.read<CurrentUserModel>().currentWordLevel == null)
          ? SvgPicture.asset(
            'assets/mascot/yeti_game_over.svg',
              semanticsLabel: 'Yeti Game Over',
              fit: BoxFit.contain,
            )
          : SvgPicture.asset(
            'assets/mascot/yeti_campfire.svg',
              semanticsLabel: 'Yeti Campfire',
              fit: BoxFit.contain,
            )
    );
  }
}
