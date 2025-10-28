import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_styles.dart';

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

  void _handleRecord() {
    if (!_isRecording) {
      // start recording and reset progress
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

  void _stopRecording() {
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
            const SizedBox(
              width: 349,
              child: Text(
                'cat',
                textAlign: TextAlign.center,
                style: AppStyles.headerText,
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
          const Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'The ',
                    style: AppStyles.subheaderText,
                  ),
                  TextSpan(
                    text: 'cat',
                    style: AppStyles.subheaderTextBold,
                  ),
                  TextSpan(
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

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
  }
}
