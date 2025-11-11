import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:readright/audio/stream/pcm_player.dart';
import 'package:readright/audio/stream/pcm_recorder.dart';
import 'package:readright/audio/stt/on_device/cheetah_assessor.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:readright/models/user_model.dart';
import 'package:readright/services/user_repository.dart';
import 'package:readright/utils/app_colors.dart';
import 'package:readright/utils/app_styles.dart';
// Audio converter helpers centralized in audio utilities
import 'package:readright/audio/audio_converter.dart';

// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';

class StudentWordPracticePage extends StatefulWidget {
  const StudentWordPracticePage({super.key});

  @override
  State<StudentWordPracticePage> createState() =>
      _StudentWordPracticePageState();
}

class _StudentWordPracticePageState extends State<StudentWordPracticePage>
    with WidgetsBindingObserver {
  double _progress = 0.0;
  bool _isProcessingRecording = false;
  bool _isRecording = false;
  Timer? _recordTimer;
  int _msElapsed = 0; // milliseconds elapsed during recording

  // late final UserModel? userModel;
  late String username;
  String? practiceWord = 'cat';

  final FlutterTts flutterTts = FlutterTts();

  // PCM player for playing back recorded audio.
  final PcmPlayer _pcmPlayer = PcmPlayer();

  // PCM recorder for live recording/streaming. We instantiate but don't start
  // until permission has been checked/confirmed.
  final PcmRecorder _pcmRecorder = PcmRecorder();

  late final CheetahAssessor _assessor;
  String? _lastTranscript;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the PCM player now. The recorder will manage microphone
    // permission and initialize itself on start().
    _pcmPlayer.init();

    // Check to see if the recorder has permissions for the microphone.
    checkRecorderPermission();

    // Initialize the assessor now that _pcmRecorder is available.
    _assessor = CheetahAssessor(pcmRecorder: _pcmRecorder, practiceWord: practiceWord!);

    // Start listening to the assessor stream after recorder is started.
    // This avoids an issue with the UI stop counter not updating if the
    // recorder is started/stopped multiple times.
    _startSTTAccessor();

    // Listen for assessment results (transcripts) and update UI.
    _assessor.stream.listen((res) {
      debugPrint('CheetahAssessor stream result: ${res.recognizedText}');
      if (!mounted) return;
      setState(() {
        _lastTranscript = res.recognizedText;
      });
    }, onError: (e) {
      debugPrint('CheetahAssessor stream error: $e');
    });

    UserRepository()
        .fetchCurrentUser()
        .then((user) {
          if (user == null) {
            debugPrint(
              'StudentWordPracticePage: No user is currently signed in.',
            );
          } else {
            debugPrint(
              'StudentWordPracticePage: User UID: ${user.id}, Username: ${user.username}, Email: ${user.email}, Role: ${user.role.name}',
            );
            username = user.username;
          }
        })
        .catchError((error) {
          debugPrint('Error fetching current user: $error');
        });

    username = 'unknown';
  }

  // Start recording for the STT assessor early.
  Future<void> _startSTTAccessor() async {
      await _assessor.start();
  }

  // Explicit check/request microphone permission for the recorder.
  // Open up app settings if permanently denied to enable Privacy settings for microphone for this app.
  Future<void> checkRecorderPermission() async {
    try {
      final perm = await _pcmRecorder.checkAndRequestPermission();
      // checkAndRequestPermission now handles UI for permanentlyDenied (dialogs/openSettings).
      // Here we only abort if permission was not granted.
      debugPrint('Microphone permission status: $perm');
      if (perm == PermissionStatus.permanentlyDenied) {
        // Build a show dialog to inform user to open settings if they
        // clicked "Don't Allow" on initial prompt.

        final open = await showDialog<bool>(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (ctx) => Platform.isIOS
              ? CupertinoAlertDialog(
                  title: const Text(
                    '"ReadRight" Microphone Permission Required',
                  ),
                  content: const Text(
                    'Microphone access is permanently denied. Open Settings to allow access for the app.',
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    CupertinoDialogAction(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      isDefaultAction: true,
                      child: const Text('Open Settings'),
                    ),
                  ],
                )
              : AlertDialog(
                  backgroundColor: const Color(
                    0xFFFAFAFA,
                  ), // slightly lighter background
                  title: const Text('Microphone permission required'),
                  content: const Text(
                    'Microphone access is permanently denied. Open Settings to allow access for the \'ReadRight\' app.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
        );
        if (open == true) {
          await openAppSettings();
        }
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Error checking microphone permission: $e')),
        );
      return;
    }
  }

  Future<void> uploadAudioFile(String filePath) async {
    final file = File(filePath);

    final fileName = path.basename(filePath);
    final storageRef = FirebaseStorage.instance.ref().child(
      'audio/$username/$practiceWord/$fileName',
    );

    try {
      debugPrint('Uploading file from: ${file.path}');

      if (!file.existsSync()) {
        debugPrint('File does not exist at: ${file.path}');
        return;
      }

      // pass empty, non null into putFile to appease firebase
      final metadata = SettableMetadata();
      await storageRef.putFile(file, metadata);

      final downloadUrl = await storageRef.getDownloadURL();

      // Save metadata to Firestore
      await FirebaseFirestore.instance.collection('audio_files').add({
        'file_name': fileName,
        'url': downloadUrl,
        'uploaded_at': FieldValue.serverTimestamp(),
        // TODO: Add STT data here
      });
    } catch (e, stackTrace) {
      debugPrint('general error: $e');
      debugPrint('stack trace:\n$stackTrace');
    }
  }

  Future<String> getAudioFilePath({String ext = 'aac'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${username}_${practiceWord}_$timestamp.$ext';
  }

  Future<void> _handleRecord() async {
    debugPrint('_handledRecord pressed ...');

    // prevent multiple taps while processing
    if (_isProcessingRecording) return;

    if (!_isRecording) {
      debugPrint('Starting recording...');

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _progress = 0.0;
        _msElapsed = 0;
      });

      // Before starting a recording, explicitly check/request microphone permission
      // try {
      final perm = await _pcmRecorder.getPermissionStatus();
      if (perm != PermissionStatus.granted) {
        await checkRecorderPermission();

        // Make sure the states for processing and recording are set
        setState(() {
          _isProcessingRecording = true;
          _isRecording = false;
        });

        return;
      }

      // Permission granted: start recording and reset progress
      try {
        // Start the PCM recorder
        await _pcmRecorder.start(
          sampleRate: 16000,
          numChannels: 1,
          bufferToMemory: true,
        );
      } catch (e) {
        debugPrint('Failed to start recorder: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Failed to start recorder: $e')),
          );
        return;
      }

      const tickMs = 100;
      _recordTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
        _msElapsed += tickMs;
        final newProgress = (_msElapsed / 7000).clamp(0.0, 1.0);
        setState(() => _progress = newProgress);

        if (_msElapsed >= 7000) _stopRecording();
      });
    } else {
      // stop early: stop the pcm recorder and then update UI
      try {
        await _pcmRecorder.stop();
      } catch (e) {
        debugPrint('Error stopping recorder: $e');
      }

    }
  }

  Future<void> _stopRecording() async {
    debugPrint('_stopRecording pressed...');

    await _pcmRecorder.stop();

    // Make sure the states for processing and recording are set
    setState(() {
      _recordTimer?.cancel();
      _recordTimer = null;

      _progress = (_msElapsed >= 7000) ? 1.0 : 0.0;
      _msElapsed = 0;
      _isRecording = false;
      _isProcessingRecording = true;
    });

    String? uploadPath;

    // Save buffered PCM bytes and encode to WAV and AAC using FFmpeg.
    // Write raw PCM to a temp file, ask FFmpeg to create WAV, then AAC.
    final pcmBytes = _pcmRecorder.getBufferedPcmBytes();
    if (pcmBytes.isNotEmpty) {
      // Produce a final transcript from the full buffered PCM bytes so the
      // user can see the result immediately. This is more deterministic
      // than relying solely on per-chunk streaming results.
      try {
        final res = await _assessor.assess(referenceText: practiceWord!, audioBytes: pcmBytes, locale: 'en-US');
        if (mounted) {
          setState(() {
            _lastTranscript = res.recognizedText;
          });
        }
      } catch (e, st) {
        debugPrint('Error running final assess on buffered PCM: $e\n$st');
      }
      // Create a raw PCM file on disk first.
      final pcmPath = await getAudioFilePath(ext: 'pcm');
      final pcmFile = File(pcmPath);
      await pcmFile.writeAsBytes(pcmBytes);

      // Create WAV from raw PCM using FFmpeg. Use `path` helper to reliably
      // swap the extension (avoids regex edge-cases where replace may fail).
      final wavPath = path.setExtension(pcmPath, '.wav');
      try {
        await AudioConverter.convertPcmToWav(
          pcmPath,
          wavPath,
          sampleRate: 16000,
        );

        // Target AAC path (same basename, .aac extension)
        final aacPath = path.setExtension(pcmPath, '.aac');

        try {
          // Prefer direct conversion from PCM -> AAC to avoid unnecessary WAV intermediate.
          await AudioConverter.convertPcmToAac(pcmPath, aacPath);
          await uploadAudioFile(aacPath);
          uploadPath = aacPath;
        } catch (e, st) {
          debugPrint(
            'PCM->AAC conversion failed: $e\n$st -- falling back to uploading WAV',
          );
          try {
            await uploadAudioFile(wavPath);
            uploadPath = wavPath;
          } catch (e3, st3) {
            debugPrint('Fallback upload (WAV) also failed: $e3\n$st3');
          }
        }
      } catch (e, st) {
        debugPrint(
          'PCM->WAV conversion failed: $e\n$st -- cannot produce WAV/AAC',
        );
      }

      // Cleanup temp files for PCM and WAV. AAC is kept for upload.
      try {
        if (await pcmFile.exists()) await pcmFile.delete();
        final wavFile = File(wavPath);
        if (await wavFile.exists() && uploadPath != wavPath) {
          await wavFile.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete temp files: $e');
      }
    } else {
      debugPrint('No PCM bytes available to save after recording.');
    }

    // If we were unable to upload any audio file, show an error and abort.
    if (uploadPath == null) {
      debugPrint('No audio file was uploaded due to previous errors.');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Recording failed to save. Please try again.'),
          ),
        );
      setState(() {
        _isProcessingRecording = false;
      });
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Verifying recording quality...'),
          duration: Duration(seconds: 2),
        ),
      );

    await Future.delayed(const Duration(seconds: 3));

    // Pass the final uploaded path (wav if converted, otherwise original)
    if (!mounted) return;
    // Instead of passing a filesystem path, pass the in-memory PCM bytes
    // so the feedback screen can replay immediately from the recorder buffer.
    Navigator.of(
      context,
    ).pushNamed('/student-word-feedback', arguments: { 'pcmBytes': _pcmRecorder.getBufferedPcmBytes(), 'transcript': _lastTranscript });

    // Reset the processing recording state after a short delay.
    // This will allow the user to record again.
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isProcessingRecording = false;
    });
  }

  Future<void> playRecording() async {
    debugPrint('playRecording called');

    await _pcmPlayer.stop();

    // Play the buffered PCM data for playback to the user.
    await _pcmPlayer.playBufferedPcm(
      _pcmRecorder.getBufferedPcmBytes(),
      sampleRate: 16000,
    );
  }

  Future<void> _handleTts(String word) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1);
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.speak(word);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // dispose audio recorder
    try {
      _pcmRecorder.dispose();
    } catch (e) {
      debugPrint('Error disposing pcm recorder: $e');
    }

    // dispose audio player
    try {
      _pcmPlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing pcm player: $e');
    }

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
              const SizedBox(height: 19),
              _buildYetiIllustration(),
              const SizedBox(height: 18),
              // _buildSentenceSection(),
              // const SizedBox(height: 0),
              _buildInstructions(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRecordButton(),

                  // Only used for testing REPLAY on this screen for
                  // debugging purposes with the audio stream.
                  // const SizedBox(width: 20),
                  // _buildReplayButton()
                ],
              ),              
              const SizedBox(height: 24),
              _buildMicrophoneDecibelLevelIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 200,
      color: AppColors.bgPrimaryGray,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(
              width: 349,
              child: Text(
                "Let's pronounce the word",
                textAlign: TextAlign.center,
                style: AppStyles.subheaderText,
              ),
            ),
            const SizedBox(height: 19),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 30),
                SizedBox(
                  child: Text(
                    '$practiceWord',
                    textAlign: TextAlign.center,
                    style: AppStyles.headerText,
                  ),
                ),
                const SizedBox(width: 10),
                _buildTtsButton(),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildYetiIllustration() {
    return SizedBox(
      width: 364,
      height: 371,
      child: SvgPicture.asset(
        'assets/mascot/yeti_music.svg',
        semanticsLabel: 'Yeti Music',
        fit: BoxFit.contain,
      ),
    );
  }

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
  //                 const TextSpan(
  //                   text: 'The ',
  //                   style: AppStyles.subheaderText,
  //                 ),
  //                 TextSpan(
  //                   text: '$practice_word',
  //                   style: AppStyles.subheaderTextBold,
  //                 ),
  //                 const TextSpan(
  //                   text: ' is sleeping on the bed.',
  //                   style: AppStyles.subheaderText,
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

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      height: 86,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC6C0).withOpacity(0.20),
      ),
      child: const Center(
        child: SizedBox(
          width: 349,
          child: Text(
            'Click the record button below so that we can hear you pronounce the word!',
            textAlign: TextAlign.center,
            style: AppStyles.chipText,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    final remaining = (_msElapsed >= 7000)
        ? 0
        : ((7000 - _msElapsed + 999) ~/ 1000);

    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _handleRecord,
      child: Container(
        width: 160,
        height: 48,
        decoration: BoxDecoration(
          color: _isRecording
              ? AppColors.buttonSecondaryRed
              : AppColors.bgPrimaryOrange,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _isProcessingRecording
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : _isRecording
                ? Row(
                    key: const ValueKey('recording'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        remaining > 0 ? 'STOP • ${remaining}s' : 'STOP',
                        style: AppStyles.buttonText,
                      ),
                    ],
                  )
                : Container(
                    key: const ValueKey('idle'),
                    child: const Text(
                      'RECORD',
                      // use AppStyles.buttonText via DefaultTextStyle? apply directly
                      style: AppStyles.buttonText,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Widget _buildReplayButton() {
  //   return GestureDetector(
  //     onTap: playRecording,
  //     child: Container(
  //       height: 48,
  //       width: 160,
  //       decoration: BoxDecoration(
  //         color: AppColors.buttonSecondaryRed,
  //         borderRadius: BorderRadius.circular(1000),
  //       ),
  //       child: const Center(
  //         child: Text(
  //           'REPLAY',
  //           style: AppStyles.buttonText,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildMicrophoneDecibelLevelIndicator() {
    // Get current dB level from recorder
    final dbLevel = _pcmRecorder.dbLevel;

    // Map dB level to a 0.0 - 1.0 range for UI representation.
    // Assuming typical microphone levels range from -60 dB (quiet) to 0 dB (loud).
    final normalizedLevel = (dbLevel / 60).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Container(
          width: double.infinity,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.progressMicrophoneFrame.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Always show the microphone icon to the left of the progress bar.
              SvgPicture.asset(
                'assets/icons/microphone-3-svgrepo-com.svg',
                width: 24,
                height: 24,
                semanticsLabel: 'Microphone',
              ),
              const SizedBox(width: 12),
              // Progress bar expands to fill remaining space.
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    // Guard value into 0.0..1.0 range.
                    value: normalizedLevel,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.progressMicrophoneDecibel,
                    ),
                    backgroundColor: AppColors.progressMicrophoneBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTtsButton() {
    return IconButton(
      icon: Icon(Icons.volume_up),
      color: Colors.green,
      iconSize: 40,
      tooltip: 'Play Example',
      onPressed: () {
        _handleTts('$practiceWord');
      },
    );
  }
}
