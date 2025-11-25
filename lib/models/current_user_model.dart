import 'package:flutter/foundation.dart';
import 'package:readright/models/attempt_model.dart';
import 'package:readright/models/class_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/models/word_model.dart';
import 'package:readright/services/attempt_repository.dart';
import 'package:readright/services/class_repository.dart';
import 'package:readright/services/user_repository.dart';
import 'package:readright/services/word_respository.dart';
import 'package:readright/utils/app_scoring.dart';
import 'package:readright/utils/enums.dart';

class CurrentUserModel extends ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;

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

  List<AttemptModel> _wordAttempts = [];
  List<AttemptModel> get wordAttempts => _wordAttempts;
  set wordAttempts(List<AttemptModel> attempts) {
    _wordAttempts = attempts;
    notifyListeners();
  }


  bool get isLoggedIn => _user != null;

  void logIn(UserModel? user) async {
    if (user == null) {
      debugPrint('CurrentUserModel: User is null, cannot log in.');
      return;
    }

    if (_user != null) {
      debugPrint('CurrentUserModel: A user is already logged in: ${_user!.username}');
      return;
    }

    debugPrint('CurrentUserModel: Logging in username ${user.username}, email ${user.email}');
    _user = user;

    // Load class section for the logged-in user
    late final clsSection;
    switch (_user?.role) {
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
        break;
      default:
        debugPrint('CurrentUserModel: Logged in with unknown role for user ${_user!.username}');
    }

    notifyListeners();
  }

  void logOut() {
    if (_user != null) {
      debugPrint('CurrentUserModel: Logging out username ${_user!.username}), email ${_user!.email}');
      UserRepository().signOutCurrentUser();
    }

    _user = null;
    _classSection = null;
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
          // Fallback to the first word if all words have passing attempts.
          practiceWordId = wordIds.first;
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