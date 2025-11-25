import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:readright/audio/stream/pcm_player.dart';
import 'package:readright/audio/stream/pcm_recorder.dart';
import 'package:readright/audio/stt/cloud/deepgram_assessor.dart';
import 'package:readright/audio/stt/on_device/cheetah_assessor.dart';
import 'package:readright/audio/stt/pronunciation_assessor.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/models/class_model.dart';
import 'package:readright/models/current_user_model.dart';
import 'package:readright/models/student_progress_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/services/class_repository.dart';
import 'package:readright/services/student_progress_repository.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/app_colors.dart';
import 'package:readright/utils/app_styles.dart';
import 'package:readright/utils/device_utility.dart';
import 'package:readright/utils/app_constants.dart';    
import 'package:readright/utils/enums.dart';    
// Audio converter helpers centralized in audio utilities
import 'package:readright/audio/audio_converter.dart';

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
  bool _isIntroductionTtsPlaying = false;
  Timer? _recordTimer;
  int _msElapsed = 0; // milliseconds elapsed during recording

  late final UserModel? _currentUser;
  ClassModel? _currentClassSection;

  WordModel? practiceWord;
  String? practiceSentenceId;
  int? practiceSentenceIndex;
  String? displaySentence = '';
  WordLevel? wordLevel;
  bool online = false;

  // ignore: constant_identifier_names
  static const int TIMER_DURATION_MS = 3000;

  // determine if there is a valid internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final response = await http.get(Uri.parse('https://www.google.com'))
          .timeout(Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void checkConnection() async {
    online = await hasInternetConnection();
    debugPrint('StudentWordPracticePage: Online: $online');
  }

  final FlutterTts flutterTts = FlutterTts();

  // PCM player for playing back recorded audio.
  final PcmPlayer _pcmPlayer = PcmPlayer();

  // PCM recorder for live recording/streaming. We instantiate but don't start
  // until permission has been checked/confirmed.
  final PcmRecorder _pcmRecorder = PcmRecorder();

  late final CheetahAssessor _cheetahAssessor;
  DeepgramAssessor? _deepgramAssessor;

  String? _lastTranscript;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Grab passed arguments from Navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        setState(() {
          practiceWord = args['practiceWord'] as WordModel?;
          wordLevel = args['wordLevel'] as WordLevel?;
        });
      } else if (args is Map) {
        setState(() {
          practiceWord = args['practiceWord'] as WordModel?;
          wordLevel = args['wordLevel'] as WordLevel?;
        });
      }
      debugPrint('StudentWordPracticePage: ${practiceWord?.text}, Word Level: ${wordLevel?.name}');

      setState(() {
        _currentUser = context.read<CurrentUserModel>().user;

        if (_currentUser != null) {
          _currentClassSection = context.read<CurrentUserModel>().classSection;

          debugPrint('StudentWordPracticePage: User UID: ${_currentUser!.id}, Username: ${_currentUser!.username}, Email: ${_currentUser!.email}, Role: ${_currentUser!.role.name}, ClassSection: ${_currentClassSection?.id}');
        } else {
          debugPrint('StudentWordPracticePage: No persisted user found.');
        }
      });

    });

    if (practiceWord != null) {
      // Initialize the PCM player now. The recorder will manage microphone
      // permission and initialize itself on start().
      _initPCMPlayer();

      // Initialize the PCM recorder if not already initialized
      _initPCMRecorder();

      // Check to see if the recorder has permissions for the microphone.
      checkRecorderPermission();

      // Start listening to the assessor stream after recorder is started.
      // This avoids an issue with the UI stop counter not updating if the
      // recorder is started/stopped multiple times.

      // Execute this line only if there is no network
      if (online == false){
        _startSTTAccessor();
      }
    }

    // Fetch a new sentence for the practice word.
    fetchNewWordSentence();

    // Handle the header TTS.
    // We're only calling this here to ensure it runs after initial state setup.
    // This will not be called again if the user traverse from
    // the student feedback screen back to this practice screen.
    _handleIntroductionTts();
  }

  // Initialize the PCM player now. The recorder will manage microphone permission.
  Future<void> _initPCMPlayer() async {
    await _pcmPlayer.init();
  }

  // Initialize the PCM recorder if not already initialized
  Future<void> _initPCMRecorder() async {
    await _pcmRecorder.init();

    // When transition back to this page from the feedback screen, ensure the recorder is stopped.
    _pcmRecorder.stop();
  }

  // Start recording for the STT assessor early.
  Future<void> _startSTTAccessor() async {
    // Initialize the assessor now that _pcmRecorder is available.
    _cheetahAssessor = CheetahAssessor(pcmRecorder: _pcmRecorder, practiceWord: practiceWord!.text);

    await _cheetahAssessor.start();
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

  // Explicit check/request microphone permission for the recorder.
  // Open up app settings if permanently denied to enable Privacy settings for microphone for this app.
  Future<void> checkRecorderPermission() async {
    try {
      final perm = await _pcmRecorder.checkAndRequestPermission();
      // checkAndRequestPermission now handles UI for permanentlyDenied (dialogs/openSettings).
      // Here we only abort if permission was not granted.
      debugPrint('StudentWordPracticePage: Microphone permission status: $perm');
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
      debugPrint('StudentWordPracticePage: Permission check error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Error checking microphone permission: $e')),
        );
      return;
    }
  }

  // Store an attempt record and student progress in Firestore.
  Future<void> storeAttempt({
    required String classId,
    required String userId,
    required String wordId,
    required String transcript,
    required String audioPath,
    required int durationMS,
    required double confidence,
    required double score,
    required AudioCodec audioCodec,
  }) async {
    final attempt = AttemptModel(
      classId: classId,
      userId: userId,
      wordId: wordId,
      speechToTextTranscript: transcript,
      audioCodec: audioCodec,
      audioPath: audioPath,
      durationMS: durationMS,
      confidence: confidence,
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

  Future<String> uploadAudioFile(String filePath) async {
    final file = File(filePath);

    final fileName = path.basename(filePath);
    final storageRef = FirebaseStorage.instance.ref().child(
      'audio/${_currentUser?.username ?? 'unknown'}/${practiceWord?.text ?? 'unknown'}/$fileName',
    );

    try {
      debugPrint('StudentWordPracticePage: Uploading file from: ${file.path}');

      if (!file.existsSync()) {
        debugPrint('StudentWordPracticePage: File does not exist at: ${file.path}');
        return '';
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
      debugPrint('StudentWordPracticePage: general error: $e');
      debugPrint('StudentWordPracticePage: stack trace:\n$stackTrace');
    }

    return storageRef.fullPath;
  }

  Future<String> getAudioFilePath({String ext = 'aac'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/${_currentUser?.username ?? 'unknown'}_${practiceWord?.text ?? 'unknown'}_$timestamp.$ext';
  }

  Future<void> _handleRecord() async {
    debugPrint('StudentWordPracticePage: _handledRecord pressed ...');

    // prevent multiple taps while processing
    if (_isProcessingRecording) return;

    if (!_isRecording) {
      debugPrint('StudentWordPracticePage: Starting recording...');

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
        debugPrint('StudentWordPracticePage: Failed to start recorder: $e');
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
        final newProgress = (_msElapsed / TIMER_DURATION_MS).clamp(0.0, 1.0);
        setState(() => _progress = newProgress);

        if (_msElapsed >= TIMER_DURATION_MS) _stopRecording();
      });
    } else {
      // stop early: stop the pcm recorder and then update UI
      try {
        await _pcmRecorder.stop();
      } catch (e) {
        debugPrint('StudentWordPracticePage: Error stopping recorder: $e');
      }

    }
  }

  Future<void> _stopRecording() async {
    debugPrint('StudentWordPracticePage: _stopRecording pressed...');

    await _pcmRecorder.stop();

    // Make sure the states for processing and recording are set
    setState(() {
      _recordTimer?.cancel();
      _recordTimer = null;

      _progress = (_msElapsed >= TIMER_DURATION_MS) ? 1.0 : 0.0;
      _msElapsed = 0;
      _isRecording = false;
      _isProcessingRecording = true;
    });

    String? uploadPath;
    AssessmentResult? attemptResult;

    // Save buffered PCM bytes and encode to WAV and AAC using FFmpeg.
    // Write raw PCM to a temp file, ask FFmpeg to create WAV, then AAC.
    final pcmBytes = _pcmRecorder.getBufferedPcmBytes();
    if (pcmBytes.isNotEmpty) {
      // Produce a final transcript from the full buffered PCM bytes so the
      // user can see the result immediately. This is more deterministic
      // than relying solely on per-chunk streaming results.

      // Create a raw PCM file on disk first.
      final pcmPath = await getAudioFilePath(ext: 'pcm');
      final pcmFile = File(pcmPath);
      await pcmFile.writeAsBytes(pcmBytes);

      // Hold reference to Firebase Storage upload path
      String? fbStoragePath;

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
          fbStoragePath = await uploadAudioFile(aacPath);
          uploadPath = aacPath;
        } catch (e, st) {
          debugPrint(
            'StudentWordPracticePage: PCM->AAC conversion failed: $e\n$st -- falling back to uploading WAV',
          );
          try {
            fbStoragePath = await uploadAudioFile(wavPath);
            uploadPath = wavPath;
          } catch (e3, st3) {
            debugPrint('StudentWordPracticePage: Fallback upload (WAV) also failed: $e3\n$st3');
          }
        }
      } catch (e, st) {
        debugPrint(
          'StudentWordPracticePage: PCM->WAV conversion failed: $e\n$st -- cannot produce WAV/AAC',
        );
      }



      try {
        _deepgramAssessor = DeepgramAssessor(audioPath: uploadPath!, practiceWord: practiceWord!.text);
        attemptResult = await _deepgramAssessor!.assess(referenceText: practiceWord!.text, audioBytes: pcmBytes, locale: 'en-US');
        final recognizedText = attemptResult?.recognizedText ?? '';
        if (mounted && recognizedText.isNotEmpty) {
          setState(() {
            _lastTranscript = recognizedText;
          });
        }
      } catch (e, st) {
        if (e is SocketException) {
          debugPrint("StudentWordPracticePage: No internet connection, falling back to local STT, Cheetah");
          try {
            attemptResult = await _cheetahAssessor.assess(referenceText: practiceWord!.text, audioBytes: pcmBytes, locale: 'en-US');
            final recognizedText = attemptResult?.recognizedText ?? '';
            if (mounted && recognizedText.isNotEmpty) {
              setState(() {
                _lastTranscript = recognizedText;
              });
            }
          } catch (e, st) {
            debugPrint('StudentWordPracticePage: Error running final assess on buffered PCM: $e\n$st');
          }
        }
        debugPrint('StudentWordPracticePage: Error running final assess on buffered PCM: $e\n$st');
      }

      // Store attempt record in Firestore
      await storeAttempt(
        classId: _currentClassSection?.id ?? 'Unknown',
        userId: _currentUser?.id ?? 'unknown_user',
        wordId: practiceWord?.id ?? 'unknown_word_id',
        transcript: _lastTranscript ?? '',
        audioPath: fbStoragePath ?? '',
        durationMS: pcmBytes.length ~/ 32, // approximate duration
        confidence: attemptResult?.confidence ?? 0.0,
        score: attemptResult?.score ?? 0.0,
        audioCodec: (() {
          final p = uploadPath ?? '';
          final ext = path.extension(p).toLowerCase();
          if (ext == '.aac') return AudioCodec.aac;
          if (ext == '.wav') return AudioCodec.wav;
          if (ext == '.pcm') return AudioCodec.pcm16;
          return AudioCodec.unknown;
        })(),
      );

      // Cleanup temp files for PCM and WAV. AAC is kept for upload.
      try {
        if (await pcmFile.exists()) await pcmFile.delete();
        final wavFile = File(wavPath);
        if (await wavFile.exists() && uploadPath != wavPath) {
          await wavFile.delete();
        }
      } catch (e) {
        debugPrint('StudentWordPracticePage: Failed to delete temp files: $e');
      }
    } else {
      debugPrint('StudentWordPracticePage: No PCM bytes available to save after recording.');
    }

    // If we were unable to upload any audio file, show an error and abort.
    if (uploadPath == null) {
      debugPrint('StudentWordPracticePage: No audio file was uploaded due to previous errors.');
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

    // Reset the word sentence if we need to practice again.
    fetchNewWordSentence();

    // Pass the final uploaded path (wav if converted, otherwise original)
    if (!mounted) return;

    // Reset the processing recording state after a short delay.
    // This will allow the user to record again.
    // await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isProcessingRecording = false;
    });

    // Instead of passing a filesystem path, pass the in-memory PCM bytes
    // so the feedback screen can replay immediately from the recorder buffer.
    Navigator.of(
      context,
    ).pushReplacementNamed(
        '/student-word-feedback',
        arguments: {
          'pcmBytes': _pcmRecorder.getBufferedPcmBytes(),
          'attemptResult': attemptResult,
          'practiceWord': practiceWord,
          'wordLevel': wordLevel,
        });
  }

  Future<void> playRecording() async {
    debugPrint('StudentWordPracticePage: playRecording called');

    await _pcmPlayer.stop();

    // Play the buffered PCM data for playback to the user.
    await _pcmPlayer.playBufferedPcm(
      _pcmRecorder.getBufferedPcmBytes(),
      sampleRate: 16000,
    );
  }

  // Handle TTS playback from asset file.
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

  void _handleDashboard() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/student-word-dashboard',
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // dispose audio recorder
    try {
      _pcmRecorder.dispose();
    } catch (e) {
      debugPrint('StudentWordPracticePage: Error disposing pcm recorder: $e');
    }

    // dispose audio player
    try {
      _pcmPlayer.dispose();
    } catch (e) {
      debugPrint('StudentWordPracticePage: Error disposing pcm player: $e');
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
        child: 
          (practiceWord == null) 
            ? Padding(
              padding: const EdgeInsets.all(36.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error',
                      style: AppStyles.headerText,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No words are available to practice for this category level. Please return to the word dashboard.',
                      style: AppStyles.subheaderText,
                    ),
                    const SizedBox(height: 24),
                    _buildDashboardButton(),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 19),
                  _buildYetiIllustration(),
                  const SizedBox(height: 18),
                  _buildSentenceSection(),
                  const SizedBox(height: 0),
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

  void _handleIntroductionTts() async {
    setState(() {
      _isIntroductionTtsPlaying = true;
      debugPrint('StudentWordPracticePage: Starting introduction TTS... $_isIntroductionTtsPlaying');
    });
    
    // Recite the header to the user on load.
    if (!_isRecording && !_isProcessingRecording) {
      Future.microtask(() async {
        // Ensure the prompt audio plays first, then the word audio.
        await _handleTts(assetPath: '${AppConstants.assetPathPhrases}lets_pronounce_the_word.mp3');
        await _handleTts(assetPath: '${AppConstants.assetPathWords}${practiceWord?.text.trim().toLowerCase()}.mp3');
        await _handleTts(assetPath: '${AppConstants.assetPathSentences}${practiceWord?.text.trim().toLowerCase()}_${practiceSentenceId}.mp3');

        setState(() {
          _isIntroductionTtsPlaying = false;
          debugPrint('StudentWordPracticePage: Ending introduction TTS... $_isIntroductionTtsPlaying');
        });
        
      });
    }
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
                    '${practiceWord?.text}',
                    textAlign: TextAlign.center,
                    style: AppStyles.headerText,
                  ),
                ),
                const SizedBox(width: 10),
                _buildTtsWordButton(),
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
                _buildHighLightedWordInSentence(
                  sentence: displaySentence ?? '',
                  wordToHighlight: practiceWord?.text ?? '',
                  textStyle: AppStyles.subheaderText,
                  highlightStyle: AppStyles.subheaderTextBold,
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

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      height: 86,
      padding: const EdgeInsets.all(10),
      // decoration: BoxDecoration(
      //   color: const Color(0xFFFFC6C0).withOpacity(0.20),
      // ),
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
    final remaining = (_msElapsed >= TIMER_DURATION_MS)
        ? 0
        : ((TIMER_DURATION_MS - _msElapsed + 999) ~/ 1000);

    debugPrint("StudentWordPracticePage: _buildRecordButton: isIntroTtsPlaying=$_isIntroductionTtsPlaying, isRecording=$_isRecording, isProcessing=$_isProcessingRecording, progress=$_progress, remaining=$remaining");
    return 
      (_isIntroductionTtsPlaying == true)
        ? Container(
            width: 160,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bgPrimaryGray,
              borderRadius: BorderRadius.circular(1000),
            ),
            child: Center(
              child: Text(
                'RECORD',
                style: AppStyles.buttonText,
              ),
            ),
          )
        : GestureDetector(
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

  Widget _buildTtsWordButton() {
    // Disable audio button while recording or processing to prevent cheating.
    return IconButton(
      icon: Icon(Icons.volume_up),
      color: (!_isRecording && !_isProcessingRecording)
              ? Colors.green
              : Colors.grey,
      iconSize: 40,
      tooltip: 'Play Practice Word',
      onPressed: () {
        (!_isRecording && !_isProcessingRecording)
          ? _handleTts(assetPath: '${AppConstants.assetPathWords}${practiceWord?.text.trim().toLowerCase()}.mp3')
          : null;
      },
    );
  }

  Widget _buildTtsWordSentenceButton() {
    // Disable audio button while recording or processing to prevent cheating.
    return IconButton(
      icon: Icon(Icons.volume_up),
      color: (!_isRecording && !_isProcessingRecording)
              ? Colors.green
              : Colors.grey,
      iconSize: 40,
      tooltip: 'Play Practice Word Sentence',
      onPressed: () {
        (!_isRecording && !_isProcessingRecording)
            ? _handleTts(assetPath: '${AppConstants.assetPathSentences}${practiceWord?.text.trim().toLowerCase()}_${practiceSentenceId}.mp3')
            : null;
      },
    );
  }

  Widget _buildDashboardButton() {
    return GestureDetector(
      onTap: _handleDashboard,
      child: Container(
        height: 44,
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.buttonPrimaryBlue,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: const Center(
          child: Text(
            'DASHBOARD',
            style: AppStyles.buttonText,
          ),
        ),
      ),
    );
  }
}
