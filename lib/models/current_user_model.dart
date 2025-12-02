import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/models/class_model.dart';
import 'package:readright/models/student_progress_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/services/class_repository.dart';
import 'package:readright/services/student_progress_repository.dart';
import 'package:readright/services/user_repository.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/app_scoring.dart';
import 'package:readright/utils/enums.dart';

class CurrentUserModel extends ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;
  set user(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  ClassModel? _classSection;
  set classSection(ClassModel? classModel) {
    _classSection = classModel;

    // Load students when class section is set
    // You can add logic here to load students related to the class section if needed
    if (_user?.role == UserRole.teacher) {
      loadStudents().then((_) {
        notifyListeners();
      });
    }
  }
  ClassModel? get classSection => _classSection;

  WordLevel? _currentWordLevel;
  WordLevel? get currentWordLevel => _currentWordLevel;
  set currentWordLevel(WordLevel? level) {
    if (_currentWordLevel != level) {
      debugPrint('CurrentUserModel: Changing current word level from ${_currentWordLevel?.name} to ${level?.name}');

      _currentWordLevel = level;

      if (level != null) {
        debugPrint('CurrentUserModel: Current word level set to ${level.name}');
        updateCurrentWordLevel();
      } else {
        debugPrint('CurrentUserModel: Current word level set to null');
      }

      notifyListeners();
    }
  }
  void updateCurrentWordLevel() async {
    if (_currentWordLevel == null || user == null) {
      debugPrint('CurrentUserModel: Cannot update student progress, level or user is null.');
      return;
    }

    await StudentProgressRepository().fetchProgressByUid(user!.id as String).then((progress) async {
      if (progress != null) {
        // Update only the currentWordLevel field
        progress = progress.copyWith(
          currentWordLevel: _currentWordLevel
        );

        await StudentProgressRepository().upsertProgress(progress);
        debugPrint('CurrentUserModel: Updated student progress with new current word level ${_currentWordLevel?.name}');
      } else {
        debugPrint('CurrentUserModel: No existing student progress found for user ${user?.id}, cannot update current word level.');
      }
    }).catchError((e) {
      debugPrint('CurrentUserModel: Error updating student progress for user ${user?.id}: $e');
    });
  }

  Map<WordLevel, bool> _wordLevelsCompleted = {};
  Map<WordLevel, bool> get wordLevelsCompleted => _wordLevelsCompleted;
  set wordLevelsCompleted(Map<WordLevel, bool> levelsCompleted) {
    _wordLevelsCompleted = levelsCompleted;

    if (levelsCompleted.isNotEmpty) {
      debugPrint('CurrentUserModel: Word levels completed updated: ${levelsCompleted.keys.map((e) => e.name).join(', ')}');
      updateWordLevelsCompleted();
    } else {
      debugPrint('CurrentUserModel: Word levels completed set to empty.');
    }

    notifyListeners();
  }

  // TODO: Need to revisit why this is not saving properly to the Firestore document.
  void updateWordLevelsCompleted() async {
    if (user == null) {
      debugPrint('CurrentUserModel: Cannot update student progress, user is null.');
      return;
    }

    await StudentProgressRepository().fetchProgressByUid(user!.id as String).then((progress) async {
      if (progress != null) {
        // Update only the wordLevelsCompleted field
        progress = progress.copyWith(
          wordLevelsCompleted: _wordLevelsCompleted,
        );

        await StudentProgressRepository().upsertProgress(progress);
        debugPrint('CurrentUserModel: Updated student progress with new current word level ${_currentWordLevel?.name}');
      } else {
        debugPrint('CurrentUserModel: No existing student progress found for user ${user?.id}, cannot update current word level.');
      }
    }).catchError((e) {
      debugPrint('CurrentUserModel: Error updating student progress for user ${user?.id}: $e');
    });
  }

  List<AttemptModel> _wordAttempts = [];
  List<AttemptModel> get wordAttempts => _wordAttempts;
  set wordAttempts(List<AttemptModel> attempts) {
    _wordAttempts = attempts;
    notifyListeners();
  }


  bool get isLoggedIn => _user != null;

  Future<void> logIn(UserModel? userModel) async {
    if (userModel == null) {
      debugPrint('CurrentUserModel: User is null, cannot log in.');
      return;
    }

    _user = userModel;

    if (_user == null) {
      debugPrint('CurrentUserModel: User is null, cannot log in.');
      return;
    }

    debugPrint('CurrentUserModel: Logging in username ${_user!.username}, email ${_user!.email}');

    // Load class section for the logged-in user
    late final clsSection;
    switch (_user!.role) {
      case UserRole.teacher:
        debugPrint('CurrentUserModel: Logged in as teacher ${_user!.username}');
        clsSection = await ClassRepository().fetchClassesByTeacher(_user!.id as String);

        if (clsSection.isEmpty) {
          debugPrint('CurrentUserModel: No class section found for teacher ${_user!.id}');
          notifyListeners();
          return;
        }
        _classSection = clsSection.first;

        await loadStudents();
        break;
      case UserRole.student:
        debugPrint('CurrentUserModel: Logged in as student ${_user!.username}');
        clsSection = await ClassRepository().fetchClassesByStudent(_user!.id as String);

        if (clsSection.isEmpty) {
          debugPrint('CurrentUserModel: No class section found for student ${_user!.id}');
          notifyListeners();
          return;
        }
        _classSection = clsSection.first;

        wordAttempts = await AttemptRepository().fetchAttemptsByUser(
          _user?.id as String,
          classId: _classSection?.id ?? 'Unknown',
        );

        // Load student progress to set current word level and completed levels
        // ignore: use_build_context_synchronously
        final studentProgress = await StudentProgressRepository().fetchProgressByUid(userModel.id as String);

        if (studentProgress?.currentWordLevel != null) {
          currentWordLevel = studentProgress!.currentWordLevel;
        } else {
          debugPrint('CurrentUserModel: No current word level found for student ${_user!.username}, defaulting to Pre-Primer.');
          currentWordLevel = fetchWordLevelsIncreasingDifficultyOrder().first;
        }

        final levelsCompleted = studentProgress?.wordLevelsCompleted;
        if (levelsCompleted != null && levelsCompleted.isNotEmpty) {
          wordLevelsCompleted = levelsCompleted;
        }
        break;
      default:
        debugPrint('CurrentUserModel: Logged in with unknown role for user ${_user!.username}');
    }

    notifyListeners();
  }

  Future<void> logOut() async{
    if (_user != null) {
      debugPrint('CurrentUserModel: Logging out username ${_user!.username}), email ${_user!.email}');
      UserRepository().signOutCurrentUser();
    }

    _user = null;
    _classSection = null;
    _currentWordLevel = null;
    _wordLevelsCompleted = {};
    _wordAttempts = [];
    notifyListeners();
  }
  
  Future<void> loadStudents() async {
    if (_classSection != null) {

      // fetch student ids syncronously and update the model when done
      await ClassRepository()
          .fetchStudentIdsByClassId(_classSection!.id as String)
          .then((ids) {
        _classSection!.studentIds = ids;
        debugPrint('CurrentUserModel: Loaded ${_classSection!.studentIds.length} students for class ${_classSection!.id}');
      }).catchError((e) {
        debugPrint('Failed to load students for class ${_classSection!.id}: $e');
      });
    }
  }

  // Compute the next word for the user to practice in the given word level.
  // Prefers unattempted words, then words with failing attempts.
  Future<WordModel?> fetchUsersNextPracticeWord(WordLevel wordLevel) async {

    try {
      // Update the current word level in the model
      if (currentWordLevel != wordLevel) {
        debugPrint('CurrentUserModel: Updating current word level to ${wordLevel.name} for next practice word fetch.');
        currentWordLevel = wordLevel;
      }

      // Make sure that attempts are up to date. This ensures that we have the latest data when 
      // calculating the next practice word.
      wordAttempts = await AttemptRepository().fetchAttemptsByUser(
          _user!.id as String,
          classId: _classSection?.id ?? 'Unknown',
        );

      final words = await WordRepository().fetchLevelWords(wordLevel);
      // Map to word text; use whereType to filter out any nulls if text is nullable.
      final wordIds = words.map((w) => w.id).whereType<String>().toList();

      if (wordIds.isEmpty) return null;
      if (wordAttempts.isEmpty) return await WordRepository().fetchWordById(wordIds.first);

      late final String practiceWordId;

      // Prefer words that have not been attempted yet.
      final unattempted = wordIds.firstWhere(
        (word) => wordAttempts.where((a) => a.wordId == word).isEmpty,
        orElse: () => '',
      );

      if (unattempted.isNotEmpty) {
        debugPrint('CurrentUserModel: Selected unattempted word $unattempted for level ${wordLevel.name}');
        practiceWordId = unattempted;
      } else {
        // If every word has been attempted, pick one that hasn't reached the passing threshold.
        final failingAttemptWordIds = wordIds.where((word) {
          final attemptsForWord = wordAttempts.where((a) => a.wordId == word).toList();
          if (attemptsForWord.isEmpty) return false; // shouldn't happen here
          final allBelow = attemptsForWord.every((a) => (a.score ?? 0.0) < AppScoring.passingThreshold);
          debugPrint('CurrentUserModel: Word $word has ${attemptsForWord.length} attempts, allBelowThreshold=$allBelow');
          return allBelow;
        }).toList();

        if (failingAttemptWordIds.isNotEmpty) {
          practiceWordId = failingAttemptWordIds.first;
        } else {
            // Mark this level as completed and advance to the next level if available.
            // Use the setter so listeners are notified.
            wordLevelsCompleted = {
            ..._wordLevelsCompleted,
            wordLevel: true,
            };

            // Determine the next level (if any) and fetch its next practice word.
            final levels = fetchWordLevelsIncreasingDifficultyOrder();
            final currentIndex = levels.indexOf(wordLevel);
            if (currentIndex >= 0 && currentIndex < levels.length - 1) {
                final nextLevel = levels[currentIndex + 1];
                debugPrint('CurrentUserModel: Level ${wordLevel.name} completed. Advancing to ${nextLevel.name}.');

                currentWordLevel = nextLevel;

                return await fetchUsersNextPracticeWord(nextLevel);
            } else {
                // No further levels, return null.
                debugPrint('CurrentUserModel: Level ${wordLevel.name} completed. No further levels.');

                // currentWordLevel = null;
                
                return null;
            }
        }
      }
      final practiceWord = await WordRepository().fetchWordById(practiceWordId);

      debugPrint('CurrentUserModel: Selected next word for level ${wordLevel.name}: ${practiceWord?.text}');
      return practiceWord;
    } catch (e) {
      debugPrint('CurrentUserModel: Error fetching next word for level ${wordLevel.name}: $e');
      return null;
    }
  }

}