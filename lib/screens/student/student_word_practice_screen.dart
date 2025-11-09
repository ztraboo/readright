import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import '../../models/user_model.dart';
import '../../services/user_repository.dart';
import 'package:flutter_tts/flutter_tts.dart';



class StudentWordPracticePage extends StatefulWidget {
  const StudentWordPracticePage({super.key});

  @override
  State<StudentWordPracticePage> createState() => _StudentWordPracticePageState();
}

class _StudentWordPracticePageState extends State<StudentWordPracticePage> {
  double _progress = 0.0;
  bool _isRecording = false;
  Timer? _recordTimer;
  int _msElapsed = 0; // milliseconds elapsed during recording
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String? _path;
  // late final UserModel? userModel;
  late String username;
  String? practice_word = 'cat';

  final FlutterTts flutterTts = FlutterTts();


  @override
  void initState() {
    super.initState();
    _recorder.openRecorder();
    _player.openPlayer();
    _requestPermission();

    UserRepository().fetchCurrentUser().then((user) {
      if (user == null) {
        debugPrint('StudentWordPracticePage: No user is currently signed in.');
      } else {
        debugPrint('StudentWordPracticePage: User UID: ${user.id}, Username: ${user.username}, Email: ${user.email}, Role: ${user.role.name}');
        username = user.username;
      }
    }).catchError((error) {
      debugPrint('Error fetching current user: $error');
    });

  }

  Future<void> _requestPermission() async {
    await Permission.microphone.request();
  }

  Future<String> getAudioFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/$timestamp.aac';
  }

  Future<void> uploadAudioFile(String filePath) async {
    final file = File(filePath);

    final fileName = path.basename(filePath);
    final storageRef = FirebaseStorage.instance.ref().child('audio/$username/$practice_word/$fileName');

    try {
      print('Uploading file from: ${file.path}');

      if (!file.existsSync()) {
        print('File does not exist at: ${file.path}');
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
      print('general error: $e');
      print('stack trace:\n$stackTrace');
    }
  }

  Future<void> _handleRecord() async {
    if (!_isRecording) {
      // start recording and reset progress

      _path = await getAudioFilePath();
      await _recorder.startRecorder(toFile: _path);

      setState(() {
        _isRecording = true;
        _progress = 0.0;
        _msElapsed = 0;
      });

      // update every 100ms for smoother progress
      const tickMs = 100;
      _recordTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
        _msElapsed += tickMs;
        final newProgress = (_msElapsed / 7000).clamp(0.0, 1.0);
        setState(() {
          _progress = newProgress;
        });

        if (_msElapsed >= 7000) {
          // reached max duration
          _stopRecording();
        }
      });
    } else {
      // stop early
      _stopRecording();
    }
  }

  Future <void> _handleTts(String word) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1);
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.speak(word);
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() => _isRecording = false);
    if (_path != null) {
      await uploadAudioFile(_path!);
    }


    _recordTimer?.cancel();
    _recordTimer = null;
    setState(() {
      _isRecording = false;
      if (_msElapsed >= 7000) {
        _progress = 1.0;
      } else {
        // stopped early: reset progress
        _progress = 0.0;
      }
      _msElapsed = 0;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Verifying recording quality...'),
          duration: Duration(seconds: 2),
        ),
      );

    await Future.delayed(const Duration(seconds: 3));
    // if (!mounted) return;
    // Only navigate if the widget is still mounted after the delay.
    if (mounted) {
      Navigator.of(context).pushNamed(
        '/student-word-feedback', arguments: _path,
      );
    }
  }

  Future<void> playRecording() async {
    if (_path != null) {
      await _player.startPlayer(fromURI: _path);
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 19),
              _buildYetiIllustration(),
              const SizedBox(height: 18),
              _buildSentenceSection(),
              const SizedBox(height: 0),
              _buildInstructions(),
              const SizedBox(height: 14),
              _buildRecordButton(),
              const SizedBox(height: 20),
              _buildProgressBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 130,
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
                    '$practice_word',
                    textAlign: TextAlign.center,
                    style: AppStyles.headerText,
                  ),
                ),
                const SizedBox(width: 10),
                _buildTtsButton(),
              ],
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
      child: SvgPicture.asset(
        'assets/mascot/yeti_music.svg',
        semanticsLabel: 'Yeti Music',
        fit: BoxFit.contain,
      ),
    );
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
                  const TextSpan(
                    text: 'The ',
                    style: AppStyles.subheaderText,
                  ),
                  TextSpan(
                    text: '$practice_word',
                    style: AppStyles.subheaderTextBold,
                  ),
                  const TextSpan(
                    text: ' is sleeping on the bed.',
                    style: AppStyles.subheaderText,
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

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      height: 86,
      padding: const EdgeInsets.all(10),
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
  final remaining = (_msElapsed >= 7000) ? 0 : ((7000 - _msElapsed + 999) ~/ 1000);

    return GestureDetector(
      onTap: _handleRecord,
      child: Container(
        width: 160,
        height: 48,
        decoration: BoxDecoration(
          color: _isRecording ? AppColors.buttonSecondaryRed : AppColors.bgPrimaryOrange,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _isRecording
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

  Widget _buildTtsButton() {
    return IconButton(
        icon: Icon(Icons.volume_up),
        color: Colors.green,
        iconSize:40,
        tooltip: 'Play Example',
        onPressed: () {
          _handleTts('$practice_word');
        }
    );
  }

  Widget _buildProgressBar() {
    return Container(
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF787878).withOpacity(0.20),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _progress,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF0088FF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
