import 'package:flutter/foundation.dart';
import 'package:readright/models/user_model.dart';
import 'package:readright/services/user_repository.dart';

class CurrentUserModel extends ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;

  bool get isLoggedIn => _user != null;

  void logIn(UserModel? user) async {
    if (user == null) {
      debugPrint('User is null, cannot log in.');
      return;
    }

    if (_user != null) {
      debugPrint('A user is already logged in: ${_user!.username}');
      return;
    }

    debugPrint('Logging in username ${user.username}, email ${user.email}');
    _user = user;
    notifyListeners();
  }

  void logOut() {
    if (_user != null) {
      debugPrint('Logging out username ${_user!.username}), email ${_user!.email}');
      UserRepository().signOutCurrentUser();
    }

    _user = null;
    notifyListeners();
  }
  
}