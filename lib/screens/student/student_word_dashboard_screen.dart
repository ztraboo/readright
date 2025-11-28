import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:readright/models/class_model.dart';

import 'package:readright/models/current_user_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/services/class_repository.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/app_colors.dart';
import 'package:readright/utils/app_scoring.dart';
import 'package:readright/utils/app_styles.dart';
import 'package:readright/utils/enums.dart';

class StudentWordDashboardPage extends StatefulWidget {
  const StudentWordDashboardPage({super.key});

  @override
  State<StudentWordDashboardPage> createState() =>
      _StudentWordDashboardPageState();
}

class _StudentWordDashboardPageState extends State<StudentWordDashboardPage> { 

  late final UserModel? _currentUser;
  late final ClassModel? _currentClassSection;
  late final List<AttemptModel> _userAttempts;
  late final String practiceWord;

  @override
  void initState() {
    super.initState();
  
    // Check for existing user session on initialization
    // If a user is already signed in, we can skip the login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentUser = context.read<CurrentUserModel>().user;
      if (_currentUser != null) {
        _currentClassSection = context.read<CurrentUserModel>().classSection;

        setState(() {
          debugPrint('StudentWordDashboardPage: User UID: ${_currentUser!.id}, Username: ${_currentUser!.username}, Email: ${_currentUser!.email}, Role: ${_currentUser!.role.name}');
        
          // Fetch attempts for the current user from the database.
          AttemptRepository().fetchAttemptsByUser(
            _currentUser?.id ?? '',
            classId: _currentClassSection?.id ?? 'Unknown',
          ).then((attempts) {
              _userAttempts = attempts;
              debugPrint('Fetched ${_userAttempts.length} attempts for user ${_currentUser?.id}');
          });

        });
      } else {
        debugPrint('StudentWordDashboardPage: No persisted user found.');
        _userAttempts = [];
      }
    });

  }

  // Returns list of word IDs for the given word level.
  Future<List<String>> _fetchLevelWords(WordLevel wordLevel) async {
    try {
      debugPrint('Fetching words for level: ${wordLevel.name}');
      final words = await WordRepository().fetchLevelWords(wordLevel);
      debugPrint('Fetched ${words.length} words for level: ${wordLevel.name}');
      return words.map((w) => w.id ?? '').toList();
    } catch (e) {
      debugPrint('Error fetching words for level ${wordLevel.name}: $e');
      return [];
    }
  }

  Future<int> _fetchLevelWordCompletedTotalByUser(WordLevel wordLevel) async {
    try {
      debugPrint('Fetching words for level: ${wordLevel.name}');
      final words = await WordRepository().fetchLevelWords(wordLevel);
      final wordIds = words.map((w) => w.id ?? '').toList();
      if (wordIds.isEmpty) return 0;

      // Count words where the user has at least one attempt with score > 0.00
      if (_userAttempts.isEmpty) return 0;
      int completed = 0;
      for (final word in wordIds) {
        final hasSuccessfulAttempt = _userAttempts.any(
          (a) => a.wordId == word && (a.score ?? 0) > AppScoring.passingThreshold,
        );
        if (hasSuccessfulAttempt) completed++;
      }
      return completed;
    } catch (e) {
      debugPrint('Error fetching words for level ${wordLevel.name}: $e');
      return 0;
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    ...fetchWordLevelsIncreasingDifficultyOrder().map((wordLevel) {
                      
                      // For each word level, fetch the words and compute progress.
                      return FutureBuilder<List<String>>(
                        future: _fetchLevelWords(wordLevel), // to prefetch words for this level
                        builder: (context, snapshot) {
                          final levelWordIds = snapshot.data ?? [];

                          final computedTotalWords = levelWordIds.length;

                          // Now fetch the completed total for this level.
                          return FutureBuilder<int>(
                            future: _fetchLevelWordCompletedTotalByUser(wordLevel),
                            builder: (context, snapshotCompleted) {
                              final completed = snapshotCompleted.data ?? 0;
                              int remaining = computedTotalWords - completed;
                              if (remaining < 0) remaining = 0;
                              final progress = computedTotalWords > 0
                                  ? completed / computedTotalWords
                                  : 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: _buildWordListCard(
                                  title: wordLevel.name,
                                  backgroundColor:
                                      wordLevel.backgroundColor.withOpacity(0.20),
                                  borderRadius: 20,
                                  icon:
                                    _buildUnLockIcon(color: Colors.green), 
                                  // wordLevel.isLocked
                                  //     ? _buildLockIcon(color: wordLevel.iconColor)
                                  //     : wordLevel.isUnlocked
                                  //         ? _buildUnLockIcon(color: wordLevel.iconColor)
                                  //         : _buildCheckIcon(),
                                  done: completed,
                                  remaining: remaining,
                                  progress: progress,
                                ),
                              );
                            },
                          );
                        },
                      );
                    }),

                    // Separator between word levels
                    const SizedBox(height: 20),
                  ],
                ),
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
      height: 280,
      color: AppColors.bgPrimaryGray,
      child: Stack(
        children: [
          Positioned(
            right: 23,
            top: 140,
            child: SizedBox(
              width: 150,
              height: 146,
              child: _buildFireIcon(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 90),
                const Text(
                  'Dashboard',
                  style: AppStyles.headerText,
                ),
                const SizedBox(height: 22),
                Container(
                  width: 90,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF292929),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
                const SizedBox(height: 26),
                const SizedBox(
                  width: 223,
                  child: Text(
                    'Select a word list below to explore best way to pronounce them. ',
                    style: AppStyles.subheaderText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordListCard({
    required String title,
    required Color backgroundColor,
    required double borderRadius,
    required Widget icon,
    required int done,
    required int remaining,
    required double progress,
  }) {
    return GestureDetector(
      onTap: () async {
          // show a little feedback while we fetch (optional)
          // showDialog(
          //   context: context,
          //   barrierDismissible: false,
          //   builder: (_) => const Center(child: CircularProgressIndicator()),
          // );

          // final WordModel? practiceWord = await context
          //     .read<CurrentUserModel>()
          //     .fetchUsersNextPracticeWord(wordLevelFromString(title));

          // remove the loading dialog
          // if (Navigator.canPop(context)) Navigator.of(context).pop();

          // If no word available, show snack or early return
          // if (practiceWord == null) {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     const SnackBar(content: Text('No practice word available')),
          //   );
          //   return;
          // }

          Navigator.pushNamedAndRemoveUntil(
            context,
            '/student-word-practice',
            (Route<dynamic> route) => false,
            arguments: {
              // 'practiceWord': practiceWord,
              'wordLevel': wordLevelFromString(title),
            },
          );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      height: 0.917,
                    ),
                  ),
                ),
                icon,
              ],
            ),
            const SizedBox(height: 20),
            _buildProgressBar(progress),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Done',
                  style: TextStyle(
                    fontFamily: 'SF Compact Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$done',
                  style: const TextStyle(
                    fontFamily: 'SF Compact Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 20),
                const Text(
                  'Remaining',
                  style: TextStyle(
                    fontFamily: 'SF Compact Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$remaining',
                  style: const TextStyle(
                    fontFamily: 'SF Compact Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 20,
      // padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Stack(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF787878).withOpacity(0.20),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (progress > 0)
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF0088FF),
                  borderRadius: BorderRadius.circular(3),
                  border: progress > 0.05 ? Border.all(color: Colors.black, width: 1) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckIcon() {
    return SvgPicture.asset(
      'assets/icons/circle-check-filled-svgrepo-com.svg',
      width: 40,
      height: 40,
      semanticsLabel: 'Green Check',
    );
  }

  Widget _buildLockIcon({required Color color}) {
    return SvgPicture.asset(
      'assets/icons/lock-svgrepo-com.svg',
      width: 40,
      height: 40,
      semanticsLabel: 'Lock',
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Widget _buildUnLockIcon({required Color color}) {
    return SvgPicture.asset(
      'assets/icons/lock-unlocked-svgrepo-com.svg',
      width: 40,
      height: 40,
      semanticsLabel: 'Unlock',
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Widget _buildFireIcon() {
    return SvgPicture.asset(
      'assets/mascot/campfire.svg',
      width: 23,
      height: 23,
      semanticsLabel: 'Campfire',
    );
  }
}
