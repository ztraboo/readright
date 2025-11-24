import 'package:flutter/foundation.dart';
import 'package:readright/models/class_model.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/services/class_repository.dart';
import 'package:readright/services/user_repository.dart';
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

}